process HLAHD {
    tag "${meta.id}"
    label 'process_high'

    conda "${moduleDir}/environment.yml"
    container "${workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container
        ? 'https://community-cr-prod.seqera.io/docker/registry/v2/blobs/sha256/7e/7e050dc8ccc26b39fe2080e2b8d702b13851d260a702609b8941b57bafd84468/data'
        : 'community.wave.seqera.io/library/bowtie2_gcc_gxx_wget:8ae2b876647fef02'}"

    input:
    tuple val(meta), path(reads), path(hlahd_directory)

    output:
    tuple val(meta), path("*_final.result.txt"), emit: hla
    tuple val("${task.process}"), val('hlahd'), val("${hlahd_version}"), emit: versions_hlahd, topic: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    hlahd_version = hlahd_directory.toString().tokenize('/').last()
    def hlahd_p = hlahd_directory ? "${hlahd_directory}/bin" : ''
    def freq_data = hlahd_directory ? "${hlahd_directory}/freq_data" : ''
    def split_file = hlahd_directory ? "${hlahd_directory}/HLA_gene.split.3.50.0.txt" : ''
    def dictionary = hlahd_directory ? "${hlahd_directory}/dictionary" : ''

    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    if (meta.single_end) {
        in_reads = [reads, reads].join(' ')
    }
    else {
        in_reads = reads
    }
    """
    export PATH=\$PATH:${hlahd_p}
    hlahd.sh \\
        -t ${task.cpus} \\
        ${args} \\
        -f ${freq_data} \\
        ${in_reads} \\
        ${split_file} \\
        ${dictionary} \\
        ${prefix} \\
        ./

    cp ${prefix}/result/${prefix}_final.result.txt ./${prefix}_final.result.txt
    """

    stub:
    hlahd_version = hlahd_directory.toString().tokenize('/').last()
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    echo ${args}


    mkdir -p ${prefix}_output
    echo "Simulated hlahd output" > ${prefix}_final.result.txt
    """
}
