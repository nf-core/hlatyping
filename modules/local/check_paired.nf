process CHECK_PAIRED {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::samtools=1.16.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.16.1--h6899075_0' :
        'quay.io/biocontainers/samtools:1.16.1--h6899075_0' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path(input), path("is_singleend.txt"), emit:reads
    path "versions.yml", emit: versions

    script:
    """
    if [ \$({ samtools view -H $input -@$task.cpus ; samtools view $input -@$task.cpus | head -n1000; } | samtools view -c -f 1  -@$task.cpus ) -gt 0 ]; then
        echo false > is_singleend.txt
    else
        echo true > is_singleend.txt
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//')
    END_VERSIONS
    """
}
