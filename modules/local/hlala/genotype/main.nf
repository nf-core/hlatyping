process HLALA {
    tag "$meta.id"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hla-la:1.0.4--h077b44d_1' :
        'quay.io/biocontainers/hla-la:1.0.4--h077b44d_1' }"

    input:
    tuple val(meta), path(bam), path(bai)
    path(graph_dir)

    output:
    tuple val(meta), path("${prefix}/hla/R1_bestguess_G.txt"), emit: hla
    tuple val(meta), path("${prefix}/hla/R1_bestguess.txt"), optional: true, emit: hla_full
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    def graph_name = task.ext.graph ?: 'PRG_MHC_GRCh38_withIMGT'
    def custom_graph = graph_dir ? "--customGraphDir ${graph_dir}" : ''
    """
    # Create working directory
    mkdir -p ${prefix}

    # Run HLA*LA
    HLA-LA.pl \\
        --BAM ${bam} \\
        --graph ${graph_name} \\
        ${custom_graph} \\
        --sampleID ${prefix} \\
        --workingDir ./ \\
        --maxThreads ${task.cpus} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hlala: 1.0.4
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}/hla
    touch ${prefix}/hla/R1_bestguess_G.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hlala: 1.0.4
    END_VERSIONS
    """
}
