process HLAHD_INSTALL {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e050dc8ccc26b39fe2080e2b8d702b13851d260a702609b8941b57bafd84468/data'
        : 'community.wave.seqera.io/library/bowtie2_gcc_gxx_wget:8ae2b876647fef02'}"

    input:
    tuple val(toolname), val(toolversion), val(toolchecksum), path(tooltarball), val(update_dict)

    output:
    path "${toolname}/${toolversion}", emit: hlahd
    tuple val("${task.process}"), val('hlahd'), val(toolversion), emit: versions_hlahd, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def update_dict_flag = update_dict ? 1 : 0
    """
    #
    # VALIDATE THE CHECKSUM OF THE PROVIDED SOFTWARE TARBALL
    #
    checksum="\$(md5sum "${tooltarball}" | cut -f1 -d' ')"
    echo "\$checksum"
    if [ "\$checksum" != "${toolchecksum}" ]; then
        echo "Checksum error for ${toolname}. Please make sure to provide the original tarball for ${toolname} version ${toolversion}" >&2
        exit 2
    fi

    mkdir -p "${toolname}/${toolversion}"

    tar -C "${toolname}/${toolversion}" -v -x --strip-components=1 -f "${tooltarball}"

    cd "${toolname}/${toolversion}"
    sh install.sh

    # UPDATE THE DICTIONARY IF REQUESTED
    if [ ${update_dict_flag} -eq 1 ]; then
        sh update_dictionary.sh
    fi

    cd ../../
    """

    stub:
    """
    mkdir -p "${toolname}/${toolversion}"
    """
}
