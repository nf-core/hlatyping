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

include { methodsDescriptionText      } from '../subworkflows/local/utils_nfcore_hlatyping_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { FASTQC                      } from '../modules/nf-core/fastqc/main'
include { MULTIQC                     } from '../modules/nf-core/multiqc/main'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'
include { OPTITYPE                    } from '../modules/nf-core/optitype/main'
include { SAMTOOLS_COLLATEFASTQ       } from '../modules/nf-core/samtools/collatefastq/main'
include { SAMTOOLS_VIEW               } from '../modules/nf-core/samtools/view/main'
include { YARA_INDEX                  } from '../modules/nf-core/yara/index/main'
include { YARA_MAPPER                 } from '../modules/nf-core/yara/mapper/main'

include { paramsSummaryMap            } from 'plugin/nf-validation'

include { paramsSummaryMultiqc        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML      } from '../subworkflows/nf-core/utils_nfcore_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HLATYPING {

    take:
    ch_samplesheet      // channel: sample fastqs parsed from --input

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // Split by input type (bam/fastq)
    ch_samplesheet
        .branch { meta, files ->
            bam : files[0].getExtension() == "bam"
            fastq : true
        }
        .set { ch_input_files }


    // determine BAM pairedness for fastq conversion
    CHECK_PAIRED (ch_input_files.bam )
    CHECK_PAIRED.out.reads
        .map {meta, reads, single_end ->
            meta["single_end"] = single_end.text.toBoolean()
            [meta, reads]
        }
        .set { ch_bam_pe_corrected }
    ch_versions = ch_versions.mix(CHECK_PAIRED.out.versions)


    //
    // MODULE: Run COLLATEFASTQ
    //
    SAMTOOLS_COLLATEFASTQ (
        ch_bam_pe_corrected
    )
    ch_versions = ch_versions.mix(SAMTOOLS_COLLATEFASTQ.out.versions)


    //
    // Filter for reads depending on pairedness
    //
    SAMTOOLS_COLLATEFASTQ.out.reads
        .map { meta, reads, reads_other, reads_singleton ->
            if (meta.single_end) {
                [ meta, reads_other ]
            }
            else {
                [meta, reads]
            }
        }
        .set { ch_filtered_bam2fq }

    ch_input_files.fastq
        .mix(ch_filtered_bam2fq)
        .map { meta, reads ->
                [ meta, file("$projectDir/data/references/hla_reference_${meta['seq_type']}.fasta") ]
        }
        .set { ch_input_with_references }


    //
    // MODULE: Run FastQC
    //
    FASTQC (
        ch_input_files.fastq
        .mix(ch_filtered_bam2fq)
    )
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]})
    ch_versions = ch_versions.mix(FASTQC.out.versions.first())


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
    ch_input_files.fastq
        .mix(ch_filtered_bam2fq)
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


    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_pipeline_software_mqc_versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))

    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
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
        ch_multiqc_logo.toList()
    )

    emit:
    multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
