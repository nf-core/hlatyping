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
    def args = task.ext.args ?: ''
    def col_name = task.ext.peptide_col_name
    prefix = task.ext.prefix ?: "${meta.id}"
    def peptides = tsv
    if (col_name) {
        def lines = tsv.text.readLines()
        def idx = lines[0].split('\t').findIndexOf { it == col_name }
        if (idx < 0) {
            error("Column '${col_name}' not found in ${tsv}")
        }
        peptides = file("${task.workDir}/${prefix}.peptides.tsv")
        peptides.text = lines.drop(1).collect { it.split('\t')[idx] }.unique().join('\n') + '\n'
    }
    """
    immunotype \\
        ${args} \\
        ${peptides} \\
        ${prefix}_typing.tsv
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_typing.tsv
    """
}
