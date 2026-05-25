process SPECHLA_TYPING {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spechla:1.0.12--py312pl5321hdef70a9_0' :
        'quay.io/biocontainers/spechla:1.0.12--py312pl5321hdef70a9_0' }"

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path("${prefix}/*.txt"), emit: results
    tuple val("${task.process}"), val('spechla'), val('1.0.12'), topic: versions, emit: versions_spechla

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ''
    """
    # Nextflow changes the container --entrypoint to /bin/bash (container default entrypoint: /usr/local/env-execute)
    # Check for container variable initialisation script and source it.
    # The spechla wrapper runs under \`set -u\` and references \$CONDA_PREFIX,
    # which under Apptainer/Singularity is otherwise unset because the entrypoint is bypassed.
    if [ -f "/usr/local/env-activate.sh" ]; then
        set +u  # Otherwise, errors out because of various unbound variables
        . "/usr/local/env-activate.sh"
        set -u
    fi

    spechla \\
        -n ${prefix} \\
        -1 ${fastq[0]} \\
        -2 ${fastq[1]} \\
        -o . \\
        -j ${task.cpus} \\
        ${args}
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    mkdir -p ${prefix}
    touch ${prefix}/hla.result.txt
    touch ${prefix}/hla.result.details.txt
    touch ${prefix}/hla.result.g.group.txt
    touch ${prefix}/HLA_{A,B,C,DPA1,DPB1,DQA1,DQB1,DRB1}_freq.txt
    touch ${prefix}/HLA_{A,B,C,DPA1,DPB1,DQA1,DQB1,DRB1}_break_points_spechap.txt
    """
}
