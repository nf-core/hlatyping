/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { CHECK_PAIRED           } from '../modules/local/check_paired'
include { HLAHD_INSTALL          } from '../modules/local/hlahd/install'
include { HLAHD                  } from '../modules/local/hlahd/genotype'
include { HLALA_PREPAREGRAPH     } from '../modules/nf-core/hlala/preparegraph/main'
include { IMMUNOTYPE             } from '../modules/local/immunotype/main'
include { SUMMARIZE_TYPING       } from '../modules/local/summarize/main'

include { paramsSummaryMultiqc   } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'
include { validateMd5            } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'
include { validateHlalaReference } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'
include { getGenomeAttribute    } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CAT_FASTQ              } from '../modules/nf-core/cat/fastq'
include { FASTQC                 } from '../modules/nf-core/fastqc/main'
include { MULTIQC                } from '../modules/nf-core/multiqc/main'
include { GUNZIP                 } from '../modules/nf-core/gunzip/main'
include { OPTITYPE               } from '../modules/nf-core/optitype/main'
include { SAMTOOLS_COLLATEFASTQ  } from '../modules/nf-core/samtools/collatefastq/main'
include { SPECHLA_EXTRACT        } from '../modules/local/spechla/extract/main'
include { SPECHLA_TYPING         } from '../modules/local/spechla/typing/main'
include { HLALA_TYPING           } from '../modules/nf-core/hlala/typing/main'
include { SAMTOOLS_VIEW          } from '../modules/nf-core/samtools/view/main'
include { UNTAR                  } from '../modules/nf-core/untar/main'
include { WGET                   } from '../modules/nf-core/wget/main'
include { YARA_INDEX             } from '../modules/nf-core/yara/index/main'
include { YARA_MAPPER            } from '../modules/nf-core/yara/mapper/main'
// Genome-alignment modules for the FASTQ -> BAM step (see GENOME ALIGNMENT section below)
include { SAMTOOLS_FAIDX         } from '../modules/nf-core/samtools/faidx/main'
include { BWAMEM2_INDEX          } from '../modules/nf-core/bwamem2/index/main'
include { STAR_GENOMEGENERATE    } from '../modules/nf-core/star/genomegenerate/main'

//
// SUBWORKFLOW: Local and installed directly from nf-core/subworkflows
//
include { FASTQ_ALIGN_BWAMEM2    } from '../subworkflows/local/fastq_align_bwamem2/main'
include { FASTQ_ALIGN_STAR       } from '../subworkflows/nf-core/fastq_align_star/main'

include { paramsSummaryMap       } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HLATYPING {
    take:
    ch_samplesheet // channel: samplesheet read in from --input
    multiqc_config
    multiqc_logo
    multiqc_methods_description
    outdir

    main:

    def tools = params.tools ?: 'optitype'
    def tool_list = tools.tokenize(",")

    ch_versions = channel.empty()
    ch_multiqc_files = channel.empty()
    ch_typings = channel.empty()

    // Split by input type (bam/fastq/tsv)
    ch_samplesheet
        .branch { meta, files ->
            tsv: files[0].getExtension() == "tsv"
            bam: files[0].getExtension() == "bam"
            fastq_multiple: (meta.single_end && files.size() > 1) || (!meta.single_end && files.size() > 2)
            fastq_single: true
        }
        .set { ch_input_files }

    // Fan the BAM branch out so each consuming tool gets an independent copy
    ch_input_files.bam
        .multiMap { meta, files ->
            for_fastq_conversion: [meta, files]
            for_hlala: [meta, files]
            for_spechla: [meta, files]
        }
        .set { ch_bam }

    //
    // MODULE: Concatenate FastQ files from same sample if required
    //
    CAT_FASTQ(ch_input_files.fastq_multiple).reads.set { ch_cat_fastq }

    /*
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        GENOME ALIGNMENT: FASTQ -> GRCh38 BAM
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        HLA*LA and SpecHLA need a whole-genome BAM. FASTQ input is aligned to GRCh38 here
        (DNA: bwa-mem2, RNA: STAR); samplesheet BAMs skip this.
    */
    def need_align = ('hlala' in tool_list) || ('spechla' in tool_list)

    def ch_aligned_hlala   = channel.empty()
    def ch_aligned_spechla = channel.empty()

    if (need_align) {
        // Split by molecule type; `gate` drives the index build, `align` feeds the aligner.
        ch_input_files.fastq_single
            .mix(ch_cat_fastq)
            .branch { meta, _reads ->
                rna: meta.seq_type == 'rna'
                dna: true
            }
            .set { ch_align_by_type }

        ch_align_by_type.dna.multiMap { meta, reads -> gate: [meta, reads]; align: [meta, reads] }.set { ch_dna }
        ch_align_by_type.rna.multiMap { meta, reads -> gate: [meta, reads]; align: [meta, reads] }.set { ch_rna }

        // Use --fasta/--fasta_fai/--bwamem2 if given, else the --genome (igenomes) entry.
        def ref_fasta   = params.fasta ?: getGenomeAttribute('fasta')
        def ref_fai     = params.fasta_fai ?: getGenomeAttribute('fasta_fai')
        def ref_bwamem2 = params.bwamem2 ?: getGenomeAttribute('bwamem2')

        def ch_gtf = params.gtf
            ? channel.value([[id: 'genome'], file(params.gtf, checkIfExists: true)])
            : channel.value([[:], []])

        // Referenced only per molecule type present, so a BAM-only run needs no reference.
        def ch_fasta_dna  = ch_dna.gate.map { _m, _r -> [[id: 'genome'], file(ref_fasta, checkIfExists: true)] }.first()
        def ch_fasta_star = ch_rna.gate.map { _m, _r -> [[id: 'genome'], file(ref_fasta, checkIfExists: true)] }.first()

        def ch_fasta = ch_fasta_dna.mix(ch_fasta_star).first()
        def ch_fai = ref_fai
            ? channel.value([[id: 'genome'], file(ref_fai, checkIfExists: true)])
            : SAMTOOLS_FAIDX(ch_fasta.map { meta, fasta -> [meta, fasta, []] }, false).fai
        def ch_fasta_fai = ch_fasta.combine(ch_fai).map { fmeta, fasta, _m, fai -> [fmeta, fasta, fai] }.first()

        // HLA*LA only matches UCSC/1000G-named references; fail fast rather than hours into the run.
        if ('hlala' in tool_list) {
            ch_fasta_fai = ch_fasta_fai.map { meta, fasta, fai -> validateHlalaReference(fai); [meta, fasta, fai] }
        }

        def ch_bwamem2 = ref_bwamem2
            ? channel.value([[id: 'bwamem2'], file(ref_bwamem2, checkIfExists: true)])
            : BWAMEM2_INDEX(ch_fasta_dna).index
        def ch_star = params.star_index
            ? channel.value([[id: 'star'], file(params.star_index, checkIfExists: true)])
            : STAR_GENOMEGENERATE(ch_fasta_star, ch_gtf).index

        FASTQ_ALIGN_BWAMEM2(ch_dna.align, ch_bwamem2, false, ch_fasta_fai)
        FASTQ_ALIGN_STAR(ch_rna.align, ch_star, ch_gtf, true, ch_fasta_fai, channel.value([[id: 'no_transcripts'], [], []]))

        def ch_align_bam = FASTQ_ALIGN_BWAMEM2.out.bam.mix(FASTQ_ALIGN_STAR.out.bam)
        def ch_align_bai = FASTQ_ALIGN_BWAMEM2.out.index.mix(FASTQ_ALIGN_STAR.out.index)
        ch_multiqc_files = ch_multiqc_files.mix(FASTQ_ALIGN_BWAMEM2.out.stats.mix(FASTQ_ALIGN_STAR.out.stats).collect { _meta, f -> f })
        ch_multiqc_files = ch_multiqc_files.mix(FASTQ_ALIGN_BWAMEM2.out.flagstat.mix(FASTQ_ALIGN_STAR.out.flagstat).collect { _meta, f -> f })
        ch_multiqc_files = ch_multiqc_files.mix(FASTQ_ALIGN_BWAMEM2.out.idxstats.mix(FASTQ_ALIGN_STAR.out.idxstats).collect { _meta, f -> f })

        // Aligned BAMs are already sorted+indexed: hlala takes bam+bai, spechla just the bam.
        ch_align_bam
            .join(ch_align_bai)
            .multiMap { meta, bam, bai ->
                for_hlala: [meta, bam, bai]
                for_spechla: [meta, [bam]]
            }
            .set { ch_aligned }
        ch_aligned_hlala = ch_aligned.for_hlala
        ch_aligned_spechla = ch_aligned.for_spechla
    }

    // determine BAM pairedness for fastq conversion
    CHECK_PAIRED(ch_bam.for_fastq_conversion)
    CHECK_PAIRED.out.reads
        .map { meta, reads, single_end ->
            meta["single_end"] = single_end.text.toBoolean()
            [meta, reads]
        }
        .set { ch_bam_pe_corrected }

    //
    // MODULE: Run COLLATEFASTQ
    //
    //  paired-end reads should not be interleaved
    def interleave = false

    SAMTOOLS_COLLATEFASTQ(
        ch_bam_pe_corrected,
        ch_bam_pe_corrected.map { meta, _files -> [[id: meta.id], [], []] },
        interleave,
    )
    SAMTOOLS_COLLATEFASTQ.out.fastq.set { ch_bam_fastq }

    ch_input_files.fastq_single
        .mix(ch_cat_fastq, ch_bam_fastq)
        .set { ch_all_fastq }

    //
    // MODULE: Run FastQC
    //
    FASTQC(
        ch_all_fastq
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect { _meta, zip -> zip })

    //
    // Run modules for each selected tool
    //
    if ("optitype" in tool_list) {

        ch_all_fastq
            .map { meta, _reads ->
                [meta, file("${projectDir}/data/references/hla_reference_${meta['seq_type']}.fasta")]
            }
            .set { ch_input_with_references }

        //
        // MODULE: Run Yara indexing on HLA reference
        //
        YARA_INDEX(
            ch_input_with_references
        )
        ch_versions = ch_versions.mix(YARA_INDEX.out.versions)


        //
        // Map sample-specific reads and index
        //
        ch_all_fastq
            .cross(YARA_INDEX.out.index)
            .multiMap { reads, index ->
                reads: reads
                index: index
            }
            .set { ch_mapping_input }


        //
        // MODULE: Run Yara mapping
        //
        // Preparation Step - Pre-mapping against HLA
        //
        // In order to avoid the internal usage of RazerS from within OptiType when
        // the input files are of type `fastq`, we perform a pre-mapping step
        // here with the `yara` mapper, and map against the HLA reference only.
        //
        YARA_MAPPER(
            ch_mapping_input.reads,
            ch_mapping_input.index,
        )
        ch_versions = ch_versions.mix(YARA_MAPPER.out.versions)

        //
        // MODULE: OptiType
        //
        OPTITYPE(
            YARA_MAPPER.out.bam.join(YARA_MAPPER.out.bai)
        )

        ch_multiqc_files = ch_multiqc_files.mix(OPTITYPE.out.hla_type.collect { _meta, tsv -> tsv })
        ch_multiqc_files = ch_multiqc_files.mix(OPTITYPE.out.coverage_plot.collect { _meta, plot -> plot })
        ch_typings = ch_typings.mix(OPTITYPE.out.hla_type.map { meta, f -> [meta.id, 'optitype', f] })
    }

    if ("spechla" in tool_list) {
        //
        // MODULE: Extract HLA reads from the genome-aligned BAM, then type with SpecHLA
        //
        SPECHLA_EXTRACT(
            ch_bam.for_spechla.mix(ch_aligned_spechla).map { meta, files -> [meta, files[0]] }
        )

        SPECHLA_TYPING(SPECHLA_EXTRACT.out.reads)
        ch_typings = ch_typings.mix(
            SPECHLA_TYPING.out.results.map { meta, files ->
                [meta.id, 'spechla', (files instanceof List ? files : [files]).find { it.name == 'hla.result.txt' }]
            }
        )
    }

    if ("immunotype" in tool_list) {
        //
        // MODULE: Run immunotype peptide-based HLA typing
        //
        IMMUNOTYPE(ch_input_files.tsv.map { meta, files -> [meta, files[0]] })
        ch_typings = ch_typings.mix(IMMUNOTYPE.out.typing.map { meta, f -> [meta.id, 'immunotype', f] })
    }

    if ("hlahd" in tool_list) {
        //
        // MODULE: Run HLAHD typing
        //
        def hlahd_meta = new groovy.json.JsonSlurper().parse(file("$projectDir/assets/software_meta.json", checkIfExists: true))['hlahd']
        def ch_hlahd_install = channel.of([
            'hlahd',
            hlahd_meta.version,
            hlahd_meta.software_md5,
            file(params.hlahd_path, checkIfExists: true),
            params.hlahd_update_reference_dict,
        ])

        HLAHD_INSTALL(ch_hlahd_install)
        HLAHD(ch_all_fastq.combine(HLAHD_INSTALL.out.hlahd))
        ch_typings = ch_typings.mix(HLAHD.out.hla.map { meta, f -> [meta.id, 'hlahd', f] })
    }

    if ( "hlala" in tool_list ) {
        //
        // MODULE: Run HLA*LA typing (requires genome-aligned BAM + BAI input).
        // RNA is excluded: HLA*LA is a DNA graph-genotyping tool (WGS/WES/long-read/assembly),
        // not splice-aware and with no validated RNA mode. Use SpecHLA for RNA.
        //
        // Samplesheet BAMs may not be BGZF -> re-encode + index here; freshly aligned BAMs already
        // are, so they bypass SAMTOOLS_VIEW and reuse their own index.
        SAMTOOLS_VIEW(
            ch_bam.for_hlala
                .filter { meta, _files -> meta.seq_type != 'rna' }
                .map { meta, files -> [meta, files, []] },
            [[:], [], []],
            [[:], []],
            [[:], []],
            'bai',
        )

        SAMTOOLS_VIEW.out.bam
            .join(SAMTOOLS_VIEW.out.bai)
            .mix(ch_aligned_hlala.filter { meta, _bam, _bai -> meta.seq_type != 'rna' })
            .set { ch_bam_with_index }

        // Graph acquisition: pre-built directory takes precedence; otherwise
        // extract from a user-provided or downloaded tarball.
        def hlala_meta = new groovy.json.JsonSlurper().parse(file("$projectDir/assets/software_meta.json", checkIfExists: true))['hlala']

        WGET(
            params.hlala_graph_dir || params.hlala_graph_tarball
                ? channel.empty()
                : channel.of([[id: hlala_meta.graph], hlala_meta.graph_url, 'tar.gz'])
        )
        ch_versions = ch_versions.mix(WGET.out.versions)

        def ch_tarball = (params.hlala_graph_tarball
                ? channel.of([[id: hlala_meta.graph], file(params.hlala_graph_tarball, checkIfExists: true)])
                : channel.empty())
            .mix(WGET.out.outfile)
            .map { meta, tarball ->
                validateMd5(tarball, hlala_meta.graph_md5, "HLA*LA graph ${tarball.name}")
                [meta, tarball]
            }

        UNTAR(ch_tarball)
        HLALA_PREPAREGRAPH(UNTAR.out.untar)

        // HLALA_TYPING needs the parent directory (--customGraphDir).
        def ch_graph_dir = (params.hlala_graph_dir
                ? channel.value(file(params.hlala_graph_dir, checkIfExists: true))
                : channel.empty())
            .mix(HLALA_PREPAREGRAPH.out.graph.map { _meta, graph -> graph.parent })
            .first()

        ch_bam_with_index
            .combine(ch_graph_dir)
            .set { ch_hlala_typing_input }

        HLALA_TYPING(ch_hlala_typing_input)
        ch_typings = ch_typings.mix(
            HLALA_TYPING.out.hla.map { meta, files ->
                [meta.id, 'hlala', (files instanceof List ? files : [files]).find { it.name == 'R1_bestguess_G.txt' }]
            }
        )
    }

    //
    // MODULE: Harmonize all tools' typing results into one summary TSV
    //
    ch_typings
        .filter { _id, _tool, f -> f != null }
        .collectFile { id, tool, f -> ["${id}__${tool}.txt", f.text] }
        .collect()
        .set { ch_summarize_in }

    SUMMARIZE_TYPING(ch_summarize_in)

    //
    // Collate and save software versions
    //
    def topic_versions = channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [process[process.lastIndexOf(':') + 1..-1], "  ${tool}: ${version}"]
        }
        .groupTuple(by: 0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    def ch_collated_versions = softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${outdir}/pipeline_info",
            name: 'nf_core_' + 'hlatyping_software_' + 'mqc_' + 'versions.yml',
            sort: true,
            newLine: true,
        )

    //
    // MODULE: MultiQC
    //
    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    def ch_summary_params = paramsSummaryMap(workflow, parameters_schema: "nextflow_schema.json")
    def ch_workflow_summary = channel.value(paramsSummaryMultiqc(ch_summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    def ch_multiqc_custom_methods_description = multiqc_methods_description
        ? file(multiqc_methods_description, checkIfExists: true)
        : file("${projectDir}/assets/methods_description_template.yml", checkIfExists: true)
    def ch_methods_description = channel.value(methodsDescriptionText(ch_multiqc_custom_methods_description))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml', sort: true))
    MULTIQC(
        ch_multiqc_files.flatten().collect().map { files ->
            [
                [id: 'hlatyping'],
                files,
                multiqc_config
                    ? file(multiqc_config, checkIfExists: true)
                    : file("${projectDir}/assets/multiqc_config.yml", checkIfExists: true),
                multiqc_logo ? file(multiqc_logo, checkIfExists: true) : [],
                [],
                [],
            ]
        }
    )

    emit:
    multiqc_report = MULTIQC.out.report.map { _meta, report -> [report] }.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions // channel: [ path(versions.yml) ]
}
