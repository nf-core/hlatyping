process HLALA_DOWNLOAD {
    tag "$graph_name"
    label 'process_single'

    conda "conda-forge::wget=1.21.4 conda-forge::coreutils=9.5"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/wget:1.21.4' :
        'biocontainers/wget:1.21.4' }"

    input:
    tuple val(graph_name), val(graph_url), val(graph_md5), path(graph_tarball)

    output:
    path "graphs", emit: graph
    path "versions.yml", emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def use_local = graph_tarball.name != 'NO_FILE'
    """
    if [ "${use_local}" = "true" ]; then
        # Use provided tarball
        TARBALL="${graph_tarball}"
    else
        # Download graph
        wget -q "${graph_url}" -O ${graph_name}.tar.gz
        TARBALL="${graph_name}.tar.gz"
    fi

    # Verify MD5 checksum
    checksum="\$(md5sum "\$TARBALL" | cut -f1 -d' ')"
    if [ "\$checksum" != "${graph_md5}" ]; then
        echo "Checksum error: expected ${graph_md5}, got \$checksum" >&2
        exit 2
    fi

    # Extract into parent directory structure for HLA*LA --customGraphDir
    mkdir -p graphs
    tar -xzf "\$TARBALL" -C graphs
    [ "${use_local}" = "false" ] && rm "\$TARBALL"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: \$(wget --version 2>&1 | head -1 | sed 's/GNU Wget //;s/ .*//')
    END_VERSIONS
    """

    stub:
    """
    mkdir -p graphs/${graph_name}
    touch graphs/${graph_name}/serializedGRAPH

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        wget: \$(wget --version 2>&1 | head -1 | sed 's/GNU Wget //;s/ .*//')
    END_VERSIONS
    """
}
