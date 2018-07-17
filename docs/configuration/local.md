# nf-core/hlatyping: Local Configuration

If running the pipeline in a local environment, we highly recommend using either Docker or Singularity.

## Docker
Docker is a great way to run nf-core/hlatyping, as it manages all software installations and allows the pipeline to be run in an identical software environment across a range of systems.

Nextflow has [excellent integration](https://www.nextflow.io/docs/latest/docker.html) with Docker, and beyond installing the two tools, not much else is required. The nf-core/hlatyping profile comes with a configuration profile for docker, making it very easy to use. 

First, install docker on your system: [Docker Installation Instructions](https://docs.docker.com/engine/installation/)

Then, simply run the analysis pipeline:
```bash
nextflow run nf-core/hlatyping -profile docker --reads '<path to your reads>'
```

Nextflow will recognise `nf-core/hlatyping` and download the pipeline from GitHub. The `-profile docker` configuration lists the [nfcore/hlatyping](https://hub.docker.com/r/nfcore/hlatyping/) image that we have created and is hosted at dockerhub, and this is downloaded.

For more information about how to work with reference genomes, see [`docs/configuration/reference_genomes.md`](docs/configuration/reference_genomes.md).

### Pipeline versions
The public docker images are tagged with the same version numbers as the code, which you can use to ensure reproducibility. When running the pipeline, specify the pipeline version with `-r`, for example `-r v1.3`. This uses pipeline code and docker image from this tagged version.


## Singularity image
Many HPC environments are not able to run Docker due to security issues. [Singularity](http://singularity.lbl.gov/) is a tool designed to run on such HPC systems which is very similar to Docker. Even better, it can use create images directly from dockerhub.

There are **two** possibilities, how you can run the pipeline with the dependent software in a Singularity container. You can either pass the container's Docker Hub url, and Nextflow will trigger Singularity to download and convert it to a Singularity container automatically. Or you give it the Singularity Hub url directly.

### From Docker Hub
To use the singularity image for a single run, use:

```
nextflow run nf-core/hlatyping -profile test_fastq -with-singularity 'docker://nfcore/hlatyping'
```

This will download the docker container from dockerhub and create a singularity image for you dynamically.

### From Singularity Hub
To use an existing container build from Singularity Hub directly, just pass the url:

```
nextflow run nf-core/hlatyping -profile test_fastq -with-singularity 'shub://nf-core/hlatyping'
```
This will pull the built container directly, without the CPU overhead and time for the container conversion.


If you intend to run the pipeline offline, nextflow will not be able to automatically download the singularity image for you. Instead, you'll have to do this yourself manually first, transfer the image file and then point to that.

First, pull the image file where you have an internet connection:

```bash
singularity pull --name nfcore-hlatyping.img docker://nfcore/hlatyping
```

Then transfer this file and run the pipeline with this path:

```bash
nextflow run /path/to/nf-core/hlatyping -with-singularity /path/to/nfcore-hlatyping.img
```
