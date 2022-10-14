/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowHlatyping.initialise(params, log)

// Check input path parameters to see if they exist
def checkPathParamList = [ params.input, params.multiqc_config ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { INPUT_CHECK } from '../subworkflows/local/input_check'

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
include { CUSTOM_DUMPSOFTWAREVERSIONS } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { GUNZIP                      } from '../modules/nf-core/gunzip/main'
include { OPTITYPE                    } from '../modules/nf-core/optitype/main'
include { CHECK_PAIRED                } from '../modules/local/check_paired'
include { SAMTOOLS_COLLATEFASTQ       } from '../modules/nf-core/samtools/collatefastq/main'
include { SAMTOOLS_VIEW               } from '../modules/nf-core/samtools/view/main'
include { YARA_INDEX                  } from '../modules/nf-core/yara/index/main'
include { YARA_MAPPER                 } from '../modules/nf-core/yara/mapper/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow HLATYPING {

    ch_versions = Channel.empty()

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    // Split by input type (bam/fastq)
    INPUT_CHECK.out
        .reads
            .branch { meta, files ->
                bam : meta.data_type == "bam"
                fastq : meta.data_type == "fastq"
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
    ch_versions = ch_versions.mix(FASTQC.out.versions)


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
    ch_versions = ch_versions.mix(OPTITYPE.out.versions)


    //
    // MODULE: Pipeline reporting
    //
    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )


    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowHlatyping.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    methods_description    = WorkflowHlatyping.methodsDescriptionText(workflow, ch_multiqc_custom_methods_description)
    ch_methods_description = Channel.value(methods_description)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    ch_multiqc_files = ch_multiqc_files.mix(FASTQC.out.zip.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(OPTITYPE.out.output.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.collect().ifEmpty([]),
        ch_multiqc_custom_config.collect().ifEmpty([]),
        ch_multiqc_logo.collect().ifEmpty([]),
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
    if (params.hook_url) {
        NfcoreTemplate.adaptivecard(workflow, params, summary_params, projectDir, log)
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
