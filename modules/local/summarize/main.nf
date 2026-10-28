process SUMMARIZE_TYPING {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://depot.galaxyproject.org/singularity/mhcgnomes:1.8.6--pyh7cba7a3_0'
        : 'quay.io/biocontainers/mhcgnomes:1.8.6--pyh7cba7a3_0'}"

    input:
    path(typings)

    output:
    path("hlatyping_results.tsv"), emit: summary
    tuple val("${task.process}"), val('mhcgnomes'), eval("python -c 'import importlib.metadata as m; print(m.version(\"mhcgnomes\"))'"), topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    summarize_hla_typing.py \\
        ${args} \\
        ${typings} \\
        -o hlatyping_results.tsv
    """

    stub:
    """
    touch hlatyping_results.tsv
    """
}
