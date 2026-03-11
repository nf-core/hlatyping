process ARCASHLA_GENOTYPE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/arcas-hla:0.6.0--hdfd78af_2':
        'biocontainers/arcas-hla:0.6.0--hdfd78af_2' }"

    input:
    tuple val(meta), path(reads)
    path(dat)

    output:
    tuple val(meta), path("*.genotype.json"), emit: genotype
    tuple val(meta), path("*.genes.json")   , emit: genes    , optional: true
    path "versions.yml"                     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def single_end = meta.single_end ? "--single" : ""
    """
    # Create local arcasHLA structure with staged dat
    ARCAS_INSTALL=\$(ls -d \$(dirname \$(which arcasHLA))/../share/arcas-hla-*/ | head -1)
    mkdir -p arcashla
    cp \${ARCAS_INSTALL}/arcasHLA arcashla/
    cp -r \${ARCAS_INSTALL}/scripts arcashla/
    ln -s \$(pwd)/${dat} arcashla/dat

    bash arcashla/arcasHLA genotype ${args} -t ${task.cpus} -o . ${single_end} ${reads}

    rm -rf arcashla

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: \$(arcasHLA --version 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+' || echo '0.6.0')
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    echo '{"sample": "${prefix}", "A": ["A*02:01", "A*24:02"], "B": ["B*07:02", "B*44:02"], "C": ["C*05:01", "C*07:02"]}' > ${prefix}.genotype.json

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: 0.6.0
    END_VERSIONS
    """
}
