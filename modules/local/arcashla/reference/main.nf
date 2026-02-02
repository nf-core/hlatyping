process ARCASHLA_REFERENCE {
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/arcas-hla:0.6.0--hdfd78af_2':
        'biocontainers/arcas-hla:0.6.0--hdfd78af_2' }"

    output:
    path "dat"          , emit: reference
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Create local arcasHLA structure
    ARCAS_INSTALL=\$(ls -d \$(dirname \$(which arcasHLA))/../share/arcas-hla-*/ | head -1)
    mkdir -p arcashla
    cp \${ARCAS_INSTALL}/arcasHLA arcashla/
    cp -r \${ARCAS_INSTALL}/scripts arcashla/
    cp -r \${ARCAS_INSTALL}/dat arcashla/

    # Clone IMGTHLA and extract hla.dat
    git clone --depth 1 https://github.com/ANHIG/IMGTHLA.git arcashla/dat/IMGTHLA
    unzip -o arcashla/dat/IMGTHLA/hla.dat.zip -d arcashla/dat/IMGTHLA

    # Build reference
    bash arcashla/arcasHLA reference --rebuild ${args}

    # Move dat to output and clean up
    mv arcashla/dat dat
    rm -rf arcashla dat/IMGTHLA/.git dat/IMGTHLA/.github dat/IMGTHLA/*.zip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: \$(arcasHLA --version 2>&1 | grep -oP '\\d+\\.\\d+\\.\\d+' || echo '0.6.0')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p dat/IMGTHLA/wmda dat/info dat/ref
    touch dat/IMGTHLA/wmda/hla_nom_p.txt dat/IMGTHLA/wmda/hla_nom_g.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: 0.6.0
    END_VERSIONS
    """
}
