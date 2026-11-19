process HLALA_INDEXGRAPH {
    tag "${meta.id}"
    label 'process_medium'
    label 'process_long'
    stageInMode 'copy'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/hla-la:1.0.4--h077b44d_1'
        : 'quay.io/biocontainers/hla-la:1.0.4--h077b44d_1'}"

    input:
    tuple val(meta), path(graph)

    output:
    tuple val(meta), path("${graph}"), emit: graph
    tuple val("${task.process}"), val('bwa'), eval('bwa 2>&1 | sed -n "/^Version/ s/Version: //p"'), topic: versions, emit: versions_bwa

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    bwa \\
        index \\
        ${args} \\
        ${graph}/extendedReferenceGenome/extendedReferenceGenome.fa
    """

    stub:
    """
    mkdir -p ${graph}/extendedReferenceGenome
    touch ${graph}/extendedReferenceGenome/extendedReferenceGenome.fa.{amb,ann,bwt,pac,sa}
    """
}
