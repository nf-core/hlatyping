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
include { CHECK_PAIRED                } from '../modules/local/check_paired'
include { HLAHD_INSTALL               } from '../modules/local/hlahd/install'
include { HLAHD                       } from '../modules/local/hlahd/genotype'
include { ARCASHLA_REFERENCE          } from '../modules/local/arcashla/reference'
include { ARCASHLA_GENOTYPE           } from '../modules/local/arcashla/genotype'

include { paramsSummaryMultiqc        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText      } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { CAT_FASTQ                   } from '../modules/nf-core/cat/fastq'
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'
include { OPTITYPE                    } from '../modules/nf-core/optitype/main'
include { SAMTOOLS_COLLATEFASTQ       } from '../modules/nf-core/samtools/collatefastq/main'
include { SAMTOOLS_VIEW               } from '../modules/nf-core/samtools/view/main'
include { YARA_INDEX                  } from '../modules/nf-core/yara/index/main'
include { YARA_MAPPER                 } from '../modules/nf-core/yara/mapper/main'
include { ARCASHLA_EXTRACT            } from '../modules/nf-core/arcashla/extract/main'

include { paramsSummaryMap            } from 'plugin/nf-schema'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HLATYPING {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    def tools = params.tools ?: 'optitype'

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Split by input type (bam/fastq)
    ch_samplesheet
        .branch { meta, files ->
            bam : files[0].getExtension() == "bam"
            fastq_multiple :
                (meta.single_end && files.size() > 1) ||
                (!meta.single_end && files.size() > 2)
            fastq_single : true
        }
        .set { ch_input_files }

    //
    // MODULE: Concatenate FastQ files from same sample if required
    //
    CAT_FASTQ(ch_input_files.fastq_multiple).reads
    .set { ch_cat_fastq }
    ch_versions = ch_versions.mix(CAT_FASTQ.out.versions.first())

    // determine BAM pairedness for fastq conversion
    CHECK_PAIRED (ch_input_files.bam )
    CHECK_PAIRED.out.reads
        .map {meta, reads, single_end ->
            meta["single_end"] = single_end.text.toBoolean()
            [meta, reads]
        }
        .set { ch_bam_pe_corrected }
    ch_versions = ch_versions.mix(CHECK_PAIRED.out.versions)


    //  paired-end reads should not be interleaved
    def interleave = false

    //
    // MODULE: Run COLLATEFASTQ
    //
    SAMTOOLS_COLLATEFASTQ (
        ch_bam_pe_corrected,
        ch_bam_pe_corrected.map{ it ->                                         // meta, fasta
            def new_id = ""
            if(it) {
                new_id = it[0].baseName
            }
            [[id:new_id], []] },
        interleave
    )
    SAMTOOLS_COLLATEFASTQ.out.fastq.set { ch_bam_fastq }
    ch_versions = ch_versions.mix(SAMTOOLS_COLLATEFASTQ.out.versions)

    ch_input_files.fastq_single
        .mix( ch_cat_fastq, ch_bam_fastq )
        .set{ ch_all_fastq }

    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_all_fastq
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())

    //
    // Run modules for each selected tool
    //
    if ( "optitype" in tools.tokenize(",") ) {

        ch_all_fastq
            .map { meta, reads ->
                    [ meta, file("$projectDir/data/references/hla_reference_${meta['seq_type']}.fasta") ]
            }
            .set { ch_input_with_references }

        //
        // MODULE: Run Yara indexing on HLA reference
        //
        YARA_INDEX (
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
        YARA_MAPPER (
            ch_mapping_input.reads,
            ch_mapping_input.index
        )
        ch_versions = ch_versions.mix(YARA_MAPPER.out.versions)

        //
        // MODULE: OptiType
        //
        OPTITYPE (
            YARA_MAPPER.out.bam.join(YARA_MAPPER.out.bai)
        )

        ch_multiqc_files = ch_multiqc_files.mix(OPTITYPE.out.hla_type.collect{it[1]})
        ch_multiqc_files = ch_multiqc_files.mix(OPTITYPE.out.coverage_plot.collect{it[1]})
        ch_versions      = ch_versions.mix(OPTITYPE.out.versions)
    }

    if ( "hlahd" in tools.tokenize(",") ) {
        //
        // MODULE: Run HLAHD typing
        //
        // Parse HLA-HD software metadata and create installation channel
        def hlahd_software_meta = file("$projectDir/assets/hlahd_software_meta.json", checkIfExists: true)
        def jsonSlurper = new groovy.json.JsonSlurper()
        def hlahd_meta = jsonSlurper.parse(hlahd_software_meta)['hlahd']
        def ch_hlahd_install = Channel.of([
            'hlahd',
            hlahd_meta.version,
            hlahd_meta.software_md5,
            file(params.hlahd_path, checkIfExists: true),
            params.hlahd_update_reference_dict,
        ])

        HLAHD_INSTALL(ch_hlahd_install)
        HLAHD(ch_all_fastq.combine(HLAHD_INSTALL.out.hlahd))
        ch_versions = ch_versions.mix(HLAHD.out.versions)
    }

    if ( "arcashla" in tools.tokenize(",") ) {
        //
        // MODULE: Run arcasHLA typing
        //
        // arcasHLA works with both BAM and FASTQ input:
        // - BAM input: Use arcasHLA extract to get HLA-mapped reads, then genotype
        // - FASTQ input: Run genotype directly on the reads
        //

        // Get or build arcasHLA reference database
        if (params.arcashla_reference) {
            // Use provided reference
            ch_arcashla_reference = Channel.fromPath(params.arcashla_reference, checkIfExists: true).collect()
        } else {
            // Build reference from IMGT/HLA
            ARCASHLA_REFERENCE()
            ch_arcashla_reference = ARCASHLA_REFERENCE.out.reference.collect()
            ch_versions = ch_versions.mix(ARCASHLA_REFERENCE.out.versions)
        }

        // For BAM input: extract HLA-mapped reads
        ARCASHLA_EXTRACT(ch_bam_pe_corrected)
        ch_versions = ch_versions.mix(ARCASHLA_EXTRACT.out.versions.first())

        // Combine extracted reads from BAM with direct FASTQ input
        ch_input_files.fastq_single
            .mix(ch_cat_fastq)
            .mix(ARCASHLA_EXTRACT.out.extracted_reads_fastq)
            .set { ch_arcashla_input }

        // Run genotyping with reference
        ARCASHLA_GENOTYPE(ch_arcashla_input, ch_arcashla_reference)
        ch_versions = ch_versions.mix(ARCASHLA_GENOTYPE.out.versions.first())
    }

    //
    // Collate and save software versions
    //
    def topic_versions = Channel.topic("versions")
        .distinct()
        .branch { entry ->
            versions_file: entry instanceof Path
            versions_tuple: true
        }

    def topic_versions_string = topic_versions.versions_tuple
        .map { process, tool, version ->
            [ process[process.lastIndexOf(':')+1..-1], "  ${tool}: ${version}" ]
        }
        .groupTuple(by:0)
        .map { process, tool_versions ->
            tool_versions.unique().sort()
            "${process}:\n${tool_versions.join('\n')}"
        }

    softwareVersionsToYAML(ch_versions.mix(topic_versions.versions_file))
        .mix(topic_versions_string)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'hlatyping_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        channel.fromPath(params.multiqc_config, checkIfExists: true) :
        channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
*/
