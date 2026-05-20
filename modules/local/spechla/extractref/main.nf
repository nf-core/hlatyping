process SPECHLA_EXTRACTREF {
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine in ['singularity', 'apptainer'] && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/spechla:1.0.11--py312pl5321hdef70a9_0' :
        'quay.io/biocontainers/spechla:1.0.11--py312pl5321hdef70a9_0' }"

    output:
    path "hla_gen.format.filter.extend.DRB.no26789.v2.fasta", emit: fasta

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    # SpecHLA bundles the reference its own bowtie2 read-collection step uses.
    # Copy it out of the container so Yara can index it as the HLA-read pre-filter.
    # Path is resolved from the spechla binary location (works for container + conda).
    cp "\$(dirname "\$(which spechla)")/../share/spechla/db/ref/hla_gen.format.filter.extend.DRB.no26789.v2.fasta" .
    """

    stub:
    """
    touch hla_gen.format.filter.extend.DRB.no26789.v2.fasta
    """
}
