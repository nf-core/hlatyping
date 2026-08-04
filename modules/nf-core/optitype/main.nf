process OPTITYPE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/mulled-v2-f3579993d544920cc7c09e8ddf77569e95ea8950:d3ee2331cb4615915b1eda5d23f231da6b0741d7-0' :
        'quay.io/biocontainers/mulled-v2-f3579993d544920cc7c09e8ddf77569e95ea8950:d3ee2331cb4615915b1eda5d23f231da6b0741d7-0' }"

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("${prefix}/*.tsv"), emit: hla_type
    tuple val(meta), path("${prefix}/*.pdf"), emit: coverage_plot
    tuple val("${task.process}"), val('optitype'), eval('grep "Version:" $(which OptiTypePipeline.py) | sed "s/Version: //g"'), emit: versions_optitype, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args            = task.ext.args ?: ''
    def solver          = task.ext.args2?.getAt("solver") ? "${task.ext.args2["solver"]}" : 'glpk'
    // GLPK is single threaded only
    def solver_threads  = "${solver}" == 'glpk' ? 1 : "${task.cpus}"
    def unpaired_weight = task.ext.args2?.getAt("unpaired_weight") ? "${task.ext.args2["unpaired_weight"]}" : 0
    def use_discordant  = task.ext.args2?.getAt("use_discordant") ? "${task.ext.args2["use_discordant"]}" : 'false'
    prefix              = task.ext.prefix ?: "${meta.id}"

    """
    touch config.txt

    echo "[mapping]" >> config.ini
    echo "razers3=razers3" >> config.ini
    echo threads="${task.cpus}" >> config.ini

    echo "[ilp]" >> config.ini
    echo "solver=${solver}" >> config.ini
    echo "threads=${solver_threads}" >> config.ini

    echo "[behavior]" >> config.ini
    echo "deletebam=true" >> config.ini
    echo "unpaired_weight=${unpaired_weight}" >> config.ini
    echo "use_discordant=${use_discordant}" >> config.ini

    OptiTypePipeline.py --${meta['seq_type']} --config config.ini ${args} --prefix "${prefix}" --outdir "${prefix}" --input ${bam}
    """

    stub:
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/${prefix}_coverage_plot.pdf
    touch ${prefix}/${prefix}_result.tsv
    """
}
