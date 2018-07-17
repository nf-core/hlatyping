# ![nfcore/hlatyping](docs/images/hlatyping_logo.png)
Precision HLA typing from next-generation sequencing data using OptiType.



[![Build Status](https://travis-ci.org/nf-core/hlatyping.svg?branch=master)](https://travis-ci.org/nf-core/hlatyping)
[![Nextflow](https://img.shields.io/badge/nextflow-%E2%89%A50.30.2-brightgreen.svg)](https://www.nextflow.io/)

[![install with bioconda](https://img.shields.io/badge/install%20with-bioconda-brightgreen.svg)](http://bioconda.github.io/)
[![Docker](https://img.shields.io/docker/automated/nfcore/hlatyping.svg)](https://hub.docker.com/r/nfcore/hlatyping)
[![https://www.singularity-hub.org/static/img/hosted-singularity--hub-%23e32929.svg](https://www.singularity-hub.org/static/img/hosted-singularity--hub-%23e32929.svg)](https://singularity-hub.org/collections/1251)



# UNDER DEVELOPMENT!


### Introduction
nf-core/hlatyping: Precision HLA typing from next-generation sequencing data using OptiType.

OptiType is a HLA genotyping algorithm based on integer linear programming. Reads of whole exome/genome/transcriptome sequencing data are mapped against a reference of known MHC class I alleles. To produce accurate 4-digit HLA genotyping predictions, all major and minor HLA-I loci are considered simultaneously to find an allele combination that maximizes the number of explained reads.  

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It comes with docker / singularity containers making installation trivial and results highly reproducible.

### Hot run
If you want to test with a single line, if the pipeline works on your system, type for **Singularity** container usage:

```bash
nextflow run nf-core/hlatyping -profile singularity,test --outdir $PWD/results
```
and for **Docker**:

```bash
nextflow run nf-core/hlatyping -profile docker,test --outdir $PWD/results
```

### Documentation
The nf-core/hlatyping pipeline comes with documentation about the pipeline, found in the `docs/` directory:

1. [Installation](docs/installation.md)
2. Pipeline configuration
    * [Local installation](docs/configuration/local.md)
    * [Adding your own system](docs/configuration/adding_your_own.md)
3. [Running the pipeline](docs/usage.md)
4. [Output and how to interpret the results](docs/output.md)
5. [Troubleshooting](docs/troubleshooting.md)

### Credits
This pipeline was written by Sven Fillinger ([sven1103](https://github.com/sven1103)) at [QBiC](http://qbic.life).
