#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    nf-core/hlatyping
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/nf-core/hlatyping
Website: https://nf-co.re/hlatyping
    Slack  : https://nfcore.slack.com/channels/hlatyping
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//params.fasta = WorkflowMain.getGenomeAttribute(params, 'fasta')

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE & PRINT PARAMETER SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

WorkflowMain.initialise(workflow, params, log)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { HLATYPING } from './workflows/hlatyping'

//
// WORKFLOW: Run main nf-core/hlatyping analysis pipeline
//
workflow NFCORE_HLATYPING {
    HLATYPING ()
}

    /*
     * Preparation - Remapping of reads against HLA reference and filtering these
     *
     * In case the user provides BAM files, a remapping step
     * is then done against the HLA reference sequence.

    process remap_to_hla {
        label 'process_medium'

        input:
        path(data_index) from params.base_index_path
        set val(pattern), file(bams) from input_data
        output:
        set val(pattern), "mapped_{1,2}.bam" into fished_reads

        script:
        def full_index = "$data_index/$base_index_name"
        if (params.single_end)
            """
            samtools bam2fq $bams > output_1.fastq
            yara_mapper -e 3 -t ${task.cpus} -f bam $full_index output_1.fastq > output_1.bam
            samtools view -@ ${task.cpus} -h -F 4 -b1 output_1.bam > mapped_1.bam
            """
        else
            """
            samtools view -@ ${task.cpus} -h -f 0x40 $bams > output_1.bam
            samtools view -@ ${task.cpus} -h -f 0x80 $bams > output_2.bam
            samtools bam2fq output_1.bam > output_1.fastq
            samtools bam2fq output_2.bam > output_2.fastq
            yara_mapper -e 3 -t ${task.cpus} -f bam $full_index output_1.fastq output_2.fastq > output.bam
            samtools view -@ ${task.cpus} -h -F 4 -f 0x40 -b1 output.bam > mapped_1.bam
            samtools view -@ ${task.cpus} -h -F 4 -f 0x80 -b1 output.bam > mapped_2.bam
            """
    }
    */
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {
    NFCORE_HLATYPING ()
}



/*
 *
 * Output Description HTML

process output_documentation {
    publishDir "${params.outdir}/pipeline_info", mode: params.publish_dir_mode

    input:
    file output_docs from ch_output_docs
    file images from ch_output_docs_images

    output:
    file "results_description.html"

    script:
    """
    markdown_to_html.py $output_docs -o results_description.html
    """
}
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
