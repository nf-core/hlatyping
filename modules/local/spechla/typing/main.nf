process SPECHLA_TYPING {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spechla:1.0.11--py312pl5321hdef70a9_0' :
        'quay.io/biocontainers/spechla:1.0.11--py312pl5321hdef70a9_0' }"

    input:
    tuple val(meta), path(fastq)

    output:
    tuple val(meta), path("${prefix}/*.{txt,fasta}"), emit: results
    // Version hardcoded: the spechla CLI exposes no parseable version string
    // (`--version` errors, `-h` prints none). Kept in sync with environment.yml.
    tuple val("${task.process}"), val('spechla'), val('1.0.11'), topic: versions, emit: versions_spechla

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ''
    """
    # TODO(remove-shim): the biocontainer is missing zless, which SpecHLA.sh calls
    # non-interactively. Remove this shim once bioconda-recipes#65570 lands and the
    # container is bumped to build _1. Tracking:
    #   https://github.com/bioconda/bioconda-recipes/pull/65570
    #   https://github.com/deepomicslab/SpecHLA/pull/73
    mkdir -p shim_bin
    printf '#!/bin/sh\\nexec zcat "\$@"\\n' > shim_bin/zless
    chmod +x shim_bin/zless
    export PATH="\$PWD/shim_bin:\$PATH"

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
    """
}
