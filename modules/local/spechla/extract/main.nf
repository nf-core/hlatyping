process SPECHLA_EXTRACT {
    tag "$meta.id"
    label 'process_low'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spechla:1.0.12--py312pl5321hdef70a9_0' :
        'quay.io/biocontainers/spechla:1.0.12--py312pl5321hdef70a9_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("${prefix}_extract_{1,2}.fq.gz"), emit: reads
    tuple val("${task.process}"), val('spechla'), val('1.0.12'), topic: versions, emit: versions_spechla

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ''
    """
    spechla-extract-hla-reads \\
        -s ${prefix} \\
        -b ${bam} \\
        -o . \\
        ${args}
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    touch ${prefix}_extract_1.fq.gz ${prefix}_extract_2.fq.gz
    """
}
