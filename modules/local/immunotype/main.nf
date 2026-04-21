process IMMUNOTYPE {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/immunotype:1.0.2--pyhdfd78af_0'
        : 'biocontainers/immunotype:1.0.2--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(peptide_tsv)

    output:
    tuple val(meta), path("${prefix}.typing.tsv"),                    emit: typing
    tuple val(meta), path("${prefix}.probabilities.tsv"),             emit: probabilities, optional: true
    tuple val("${task.process}"), val('immunotype'), eval("immunotype --version | cut -d' ' -f3"), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix   = task.ext.prefix ?: "${meta.id}"
    """
    awk -F '\\t' '
        NR==1 {
            for (i=1; i<=NF; i++) if (\$i == "sequence") col=i
            if (!col) { print "ERROR: sequence column not found in ${peptide_tsv}" > "/dev/stderr"; exit 1 }
            next
        }
        !seen[\$col]++ { print \$col }
    ' ${peptide_tsv} > ${prefix}.peptides.tsv

    immunotype \\
        ${args} \\
        ${prefix}.peptides.tsv \\
        ${prefix}.typing.tsv
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.typing.tsv
    """
}
