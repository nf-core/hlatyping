process CHECK_PAIRED {
    tag "$meta.id"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::samtools=1.15.1" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.15.1--h1170115_0' :
        'quay.io/biocontainers/samtools:1.15.1--h1170115_0' }"

    input:
    tuple val(meta), path(input)

    output:
    tuple val(meta), path(input), path("is_singleend.txt"), emit:reads

    script:
    """
    if [ \$({ samtools view -H $input -@$task.cpus ; samtools view $input -@$task.cpus | head -n1000; } | samtools view -c -f 1  -@$task.cpus ) -gt 0 ]; then
        echo false > is_singleend.txt
    else
        echo true > is_singleend.txt
    fi
    """
}
