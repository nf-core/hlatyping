process SPECHLA_TYPING {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spechla:1.0.11--py312pl5321hdef70a9_0' :
        'quay.io/biocontainers/spechla:1.0.11--py312pl5321hdef70a9_0' }"

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${prefix}/hla.result.txt"),                          emit: hla_type
    tuple val(meta), path("${prefix}/hla.result.details.txt"),                  emit: details
    tuple val(meta), path("${prefix}/hla.result.g.group.txt"),                  emit: g_group,       optional: true
    tuple val(meta), path("${prefix}/HLA_*.rephase.vcf.gz"),                    emit: phased_vcfs,   optional: true
    tuple val(meta), path("${prefix}/hla.allele.*.HLA_*.fasta"),                emit: alleles_fasta, optional: true
    tuple val(meta), path("${prefix}/HLA_*_freq.txt"),                          emit: freq,          optional: true
    tuple val("${task.process}"), val('spechla'), val('1.0.11'), topic: versions, emit: versions_spechla

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: meta.id
    def args = task.ext.args ?: ''
    """
    spechla -n ${prefix} -1 ${reads[0]} -2 ${reads[1]} -o ${prefix} -j ${task.cpus} ${args}
    """

    stub:
    prefix = task.ext.prefix ?: meta.id
    """
    mkdir -p ${prefix}
    touch ${prefix}/hla.result.txt
    touch ${prefix}/hla.result.details.txt
    """
}
