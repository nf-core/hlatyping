process IMMUNOTYPE {
    tag "${meta.id}"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/immunotype:1.0.2--pyhdfd78af_0'
        : 'biocontainers/immunotype:1.0.2--pyhdfd78af_0'}"

    input:
    tuple val(meta), path(tsv)

    output:
    tuple val(meta), path("${prefix}_typing.tsv"), emit: typing
    tuple val(meta), path("${prefix}_probabilities.tsv"), emit: probabilities, optional: true
    tuple val("${task.process}"), val('immunotype'), eval("immunotype --version | cut -d' ' -f3"), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    def args = task.ext.args ?: ''
    def col_name = task.ext.peptide_col_name
    // If peptide_col_name is set, extract that column from a header TSV; otherwise the input is already a headerless peptide list and is passed through.
    def prepare = col_name
        ? "awk -F'\\t' -v c='${col_name}' 'NR==1{for(i=1;i<=NF;i++) if(\$i==c) k=i; next} !seen[\$k]++{print \$k}' ${tsv} > ${prefix}_immunotype_input.tsv"
        : "cp ${tsv} ${prefix}_immunotype_input.tsv"
    """
    ${prepare}

    immunotype \\
        ${args} \\
        ${prefix}_immunotype_input.tsv \\
        ${prefix}_typing.tsv
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_typing.tsv
    """
}
