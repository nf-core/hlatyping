process ARCASHLA_REFERENCE {
    label 'process_medium'

    // Need to run as root to modify container's dat directory
    containerOptions { workflow.containerEngine == 'docker' ? '--user 0:0' : '' }

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/arcas-hla:0.6.0--hdfd78af_2':
        'biocontainers/arcas-hla:0.6.0--hdfd78af_2' }"

    output:
    path "reference"    , emit: reference
    path "versions.yml" , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def VERSION = "0.6.0" // WARN: Version information not provided by tool on CLI. Please update this string when bumping container versions.

    """
    # Find arcasHLA installation path (resolve glob and get first match)
    ARCAS_SHARE=\$(dirname \$(which arcasHLA))/../share
    ARCAS_PATH=\$(ls -d \${ARCAS_SHARE}/arcas-hla-*/ | head -1)

    # Copy the existing dat directory content (contains info/parameters.json needed by reference.py)
    # before cloning IMGTHLA database
    mkdir -p dat
    cp -r \${ARCAS_PATH}/dat/* dat/ 2>/dev/null || true

    # Clone IMGTHLA database to work directory
    # This works around arcasHLA bug where check_ref() calls build_convert()
    # before ensuring the IMGTHLA database exists
    git clone --depth 1 https://github.com/ANHIG/IMGTHLA.git dat/IMGTHLA

    # Extract hla.dat from zip (arcasHLA expects unzipped file)
    cd dat/IMGTHLA
    unzip -o hla.dat.zip
    cd ../..

    # Link our local dat directory to arcasHLA's expected location
    rm -rf \${ARCAS_PATH}/dat
    ln -s \$(readlink -f dat) \${ARCAS_PATH}/dat

    # Now build the reference (arcasHLA will detect IMGTHLA exists and build from it)
    arcasHLA reference --rebuild ${args}

    # Clean up: remove .git directory and zip files to reduce output size
    rm -rf dat/IMGTHLA/.git dat/IMGTHLA/.gitattributes dat/IMGTHLA/.github
    rm -f dat/IMGTHLA/*.zip

    # Copy/move the reference data to output directory
    mv dat reference

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: 0.6.0
    END_VERSIONS
    """

    stub:
    """
    mkdir -p reference/IMGTHLA/wmda
    echo "stub" > reference/IMGTHLA/wmda/hla_nom_p.txt
    echo "stub" > reference/IMGTHLA/wmda/hla_nom_g.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        arcashla: 0.6.0
    END_VERSIONS
    """
}
