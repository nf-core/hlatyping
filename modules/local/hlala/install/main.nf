process HLALA_INSTALL {
    tag "$graph_name"
    label 'process_single'

    conda "bioconda::hla-la=1.0.4"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/hla-la:1.0.4--h077b44d_1' :
        'quay.io/biocontainers/hla-la:1.0.4--h077b44d_1' }"

    input:
    tuple val(graph_name), val(graph_url), val(graph_md5), path(graph_tarball)

    output:
    path "${graph_name}", emit: graph
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

    # Extract and cleanup
    tar -xzf "\$TARBALL"
    [ "${use_local}" = "false" ] && rm "\$TARBALL"

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hlala_graph: ${graph_name}
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${graph_name}
    touch ${graph_name}/serializedGRAPH

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        hlala_graph: ${graph_name}
    END_VERSIONS
    """
}
