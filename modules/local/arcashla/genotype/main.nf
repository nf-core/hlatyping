process ARCASHLA_GENOTYPE {
    tag "$meta.id"
    label 'process_medium'

    // Need to run as root to modify container's dat directory
    containerOptions { workflow.containerEngine == 'docker' ? '--user 0:0' : '' }

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/arcas-hla:0.6.0--hdfd78af_2':
        'biocontainers/arcas-hla:0.6.0--hdfd78af_2' }"

    input:
    tuple val(meta), path(reads)
    path(reference)

    output:
    tuple val(meta), path("*.genotype.json"), emit: genotype
    tuple val(meta), path("*.genes.json")   , emit: genes    , optional: true
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def single_end = meta.single_end ? "--single" : ""
    def VERSION = "0.6.0" // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    # Link reference data to arcasHLA's expected location
    ARCAS_SHARE=\$(dirname \$(which arcasHLA))/../share
    ARCAS_PATH=\$(ls -d \${ARCAS_SHARE}/arcas-hla-*/ | head -1)
    rm -rf \${ARCAS_PATH}/dat
    ln -s \$(readlink -f ${reference}) \${ARCAS_PATH}/dat

    arcasHLA \\
        genotype \\
        ${args} \\
        -t ${task.cpus} \\
        -o . \\
        ${single_end} \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: ${VERSION}
    END_VERSIONS
    """

    stub:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '{"sample": "${prefix}", "A": ["A*02:01", "A*24:02"], "B": ["B*07:02", "B*44:02"], "C": ["C*05:01", "C*07:02"]}' > ${prefix}.genotype.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: 0.6.0
    END_VERSIONS
    """
}
