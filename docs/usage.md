# nf-core/hlatyping: Usage

## Table of contents

<!-- Install Atom plugin markdown-toc-auto for this ToC to auto-update on save -->
<!-- TOC START min:2 max:3 link:true asterisk:true update:true -->
* [Table of contents](#table-of-contents)
* [Introduction](#introduction)
* [Running the pipeline](#running-the-pipeline)
  * [Updating the pipeline](#updating-the-pipeline)
  * [Reproducibility](#reproducibility)
* [Main arguments](#main-arguments)
  * [`-profile`](#-profile)
  * [`--reads`](#--reads)
  * [`--singleEnd`](#--singleend)
* [Reference genomes](#reference-genomes)
  * [`--genome` (using iGenomes)](#--genome-using-igenomes)
  * [`--fasta`](#--fasta)
  * [`--igenomesIgnore`](#--igenomesignore)
* [Job resources](#job-resources)
  * [Automatic resubmission](#automatic-resubmission)
  * [Custom resource requests](#custom-resource-requests)
* [AWS Batch specific parameters](#aws-batch-specific-parameters)
  * [`--awsqueue`](#--awsqueue)
  * [`--awsregion`](#--awsregion)
* [Other command line parameters](#other-command-line-parameters)
  * [`--outdir`](#--outdir)
  * [`--email`](#--email)
  * [`-name`](#-name)
  * [`-resume`](#-resume)
  * [`-c`](#-c)
  * [`--custom_config_version`](#--custom_config_version)
  * [`--custom_config_base`](#--custom_config_base)
  * [`--max_memory`](#--max_memory)
  * [`--max_time`](#--max_time)
  * [`--max_cpus`](#--max_cpus)
  * [`--plaintext_email`](#--plaintext_email)
  * [`--monochrome_logs`](#--monochrome_logs)
  * [`--multiqc_config`](#--multiqc_config)
<!-- TOC END -->


## Introduction
Nextflow handles job submissions on SLURM or other environments, and supervises running the jobs. Thus the Nextflow process must run until the pipeline is finished. We recommend that you put the process running in the background through `screen` / `tmux` or similar tool. Alternatively you can run nextflow within a cluster job submitted your job scheduler.

It is recommended to limit the Nextflow Java virtual machines memory. We recommend adding the following line to your environment (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```

<!-- TODO nf-core: Document required command line parameters to run the pipeline-->

## Running the pipeline
The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/hlatyping --reads '*_R{1,2}.fastq.gz' -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work            # Directory containing the nextflow working files
results         # Finished results (configurable, see below)
.nextflow_log   # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

### Updating the pipeline
When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/hlatyping
```

or run it with:

```bash
nextflow run -latest nf-core/hlatyping
```


### Reproducibility
It's a good idea to **specify** a **pipeline version** when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/hlatyping releases page](https://github.com/nf-core/hlatyping/releases) and find the latest version number - numeric only (eg. `1.0.0`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.0.0`. An example run command could look like this:

```bash
nextflow run -r 1.0.0 nf-core/hlatyping -profile docker,test
```

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future.


## Main arguments

### `-profile`
Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments. Note that multiple profiles can be loaded, for example: `-profile docker` - the order of arguments is important!

If `-profile` is not specified at all the pipeline will be run locally and expects all software to be installed and available on the `PATH`.

* `awsbatch`
  * A generic configuration profile to be used with AWS Batch.
* `conda`
  * A generic configuration profile to be used with [conda](https://conda.io/docs/)
  * Pulls most software from [Bioconda](https://bioconda.github.io/)
* `docker`
  * A generic configuration profile to be used with [Docker](http://docker.com/)
  * Runs using the `local` executor and pulls software from dockerhub: [`nfcore/hlatyping`](http://hub.docker.com/r/nfcore/hlatyping/)
* `singularity`
  * A generic configuration profile to be used with [Singularity](https://www.sylabs.io/guides/2.5.1/user-guide/)
  * Runs using the `local` executor and pulls software from Singularity Hub: [`nf-core/hlatyping`](https://singularity-hub.org/collections/1251)
* `aws`
  * A starter configuration for running the pipeline on Amazon Web Services. Uses docker and Spark.
  * See [`docs/configuration/aws.md`](configuration/aws.md)
* `standard`
  * The default profile, used if `-profile` is not specified at all. Runs locally and expects all software to be installed and available on the `PATH`.
  * This profile is mainly designed to be used as a starting point for other configurations and is inherited by most of the other profiles.
* `none`
  * No configuration at all. Useful if you want to build your own config from scratch and want to avoid loading in the default `base` config profile (not recommended).
* `test`
  * A profile with a complete configuration for automated testing
  * Includes links to test data so needs no other parameters

### `--reads`
Use this to specify the location of your input FastQ files. For example:

```bash
--reads 'path/to/data/sample_*_{1,2}.fastq'
```

Please note the following requirements:

1. The path must be enclosed in quotes
2. The path must have at least one `*` wildcard character
3. When using the pipeline with paired end data, the path must use `{1,2}` notation to specify read pairs.

If left unspecified, a default pattern is used: `data/*{1,2}.fastq.gz`

### `--singleEnd`
By default, the pipeline expects paired-end data. If you have single-end data, you need to specify `--singleEnd` on the command line when you launch the pipeline. A normal glob pattern, enclosed in quotation marks, can then be used for `--reads`. For example:

```bash
--singleEnd --reads '*.fastq'
```

It is not possible to run a mixture of single-end and paired-end files in one run.

### `--bam`

<<<<<<< HEAD
By default, the pipeline expects input data as **.fastq{.gz}**. You can also provide **.bam** files as input and combine it with the `--singleEnd` option, if necessary.
=======
## Reference genomes
>>>>>>> TEMPLATE

This will trigger the pipeline to extract the reads from the bam file and remap them against the HLA reference sequence, using the [`yara`]
https://github.com/seqan/seqan/tree/master/apps/yara) mapper. Indices and references are shipped with this pipeline, have a look in the [`./data`](https://github.com/nf-core/hlatyping/tree/master/data) folder of this repository.

### `--seqtype`

By default, the pipeline assumes DNA as sequence type. In case you are having RNA, just provide the option with `--seqtype 'rna'`.

### `--solver`

By default, the pipeline uses the [`glpk`](https://www.gnu.org/software/glpk/) IP solver. With this pipeline, there is also native support for the [`cbc`](https://projects.coin-or.org/Cbc) solver, just pass it as argument with `--solver 'cbc'`, and the pipeline will run OptiType using this IP solver.

If you want to use a different solver, then you have to provide it in the `./environment.yml` conda cofiguration file, which is used in the container built. This requires a valid conda recipe of course, and we encourage the creation of one, if not already present on Anaconda cloud.

### `--enumerations`

<<<<<<< HEAD
By default, the pipeline will do one enumeration (`--enumerations 1`). If you want OptiType to output the optimal solution and the top N-1 suboptimal solutions in the result file, specify the number of enumerations accordingly.

### `--beta`
=======
<!-- TODO nf-core: Update reference genome example according to what is needed -->

```nextflow
params {
  genomes {
    'GRCh37' {
      fasta   = '<path to the genome fasta file>' // Used if no star index given
    }
    // Any number of additional genomes, key is used with --genome
  }
}
```

<!-- TODO nf-core: Describe reference path flags -->
### `--fasta`
If you prefer, you can specify the full path to your reference genome when you run the pipeline:
>>>>>>> TEMPLATE

By default, the pipeline uses a beta value of 0.009. The constant beta weights the regularization term of the underlying integer linear program to account for homozygosity since the formulation favors heterozygous allele combinations. Beta represents the proportion of reads that need to be additionally explained by a chosen allele combination in order to choose heterzygous solutions over homzygous solutions. Evaluation of different values for beta showed the best performance with 0.009. Please refer to the original publication of OptiType (doi: 10.1093/bioinformatics/btu548) for details.

### `--prefix`
A string prefix for the output directory used. The default String is empty.

### `--igenomesIgnore`
Do not load `igenomes.config` when running the pipeline. You may choose this option if you observe clashes between custom parameters and those supplied in `igenomes.config`.

## Job resources
### Automatic resubmission
Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the steps in the pipeline, if the job exits with an error code of `143` (exceeded requested resources) it will automatically resubmit with higher requests (2 x original, then 3 x original). If it still fails after three times then the pipeline is stopped.

### Custom resource requests
Wherever process-specific requirements are set in the pipeline, the default value can be changed by creating a custom config file. See the files hosted at [`nf-core/configs`](https://github.com/nf-core/configs/tree/master/conf) for examples.

If you are likely to be running `nf-core` pipelines regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter (see definition below). You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

If you have any questions or issues please send us a message on [Slack](https://nf-core-invite.herokuapp.com/).

## AWS Batch specific parameters
Running the pipeline on AWS Batch requires a couple of specific parameters to be set according to your AWS Batch configuration. Please use the `-awsbatch` profile and then specify all of the following parameters.
### `--awsqueue`
The JobQueue that you intend to use on AWS Batch.
### `--awsregion`
The AWS region to run your job in. Default is set to `eu-west-1` but can be adjusted to your needs.

Please make sure to also set the `-w/--work-dir` and `--outdir` parameters to a S3 storage bucket of your choice - you'll get an error message notifying you if you didn't.

## Other command line parameters

<!-- TODO nf-core: Describe any other command line flags here -->

### `--outdir`
The output directory where the results will be saved.

### `--email`
Set this parameter to your e-mail address to get a summary e-mail with details of the run sent to you when the workflow exits. If set in your user config file (`~/.nextflow/config`) then you don't need to specify this on the command line for every run.

### `-name`
Name for the pipeline run. If not specified, Nextflow will automatically generate a random mnemonic.

This is used in the MultiQC report (if not default) and in the summary HTML / e-mail (always).

**NB:** Single hyphen (core Nextflow option)

### `-resume`
Specify this when restarting a pipeline. Nextflow will used cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously.

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

**NB:** Single hyphen (core Nextflow option)

### `-c`
Specify the path to a specific config file (this is a core NextFlow command).

**NB:** Single hyphen (core Nextflow option)

Note - you can use this to override pipeline defaults.

### `--custom_config_version`
Provide git commit id for custom Institutional configs hosted at `nf-core/configs`. This was implemented for reproducibility purposes. Default is set to `master`.

```bash
## Download and use config file with following git commid id
--custom_config_version d52db660777c4bf36546ddb188ec530c3ada1b96
```

### `--custom_config_base`
If you're running offline, nextflow will not be able to fetch the institutional config files
from the internet. If you don't need them, then this is not a problem. If you do need them,
you should download the files from the repo and tell nextflow where to find them with the
`custom_config_base` option. For example:

```bash
## Download and unzip the config files
cd /path/to/my/configs
wget https://github.com/nf-core/configs/archive/master.zip
unzip master.zip

## Run the pipeline
cd /path/to/my/data
nextflow run /path/to/pipeline/ --custom_config_base /path/to/my/configs/configs-master/
```

> Note that the nf-core/tools helper package has a `download` command to download all required pipeline
> files + singularity containers + institutional configs in one go for you, to make this process easier.

### `--max_memory`
Use to set a top-limit for the default memory requirement for each process.
Should be a string in the format integer-unit. eg. `--max_memory '8.GB'`

### `--max_time`
Use to set a top-limit for the default time requirement for each process.
Should be a string in the format integer-unit. eg. `--max_time '2.h'`

### `--max_cpus`
Use to set a top-limit for the default CPU requirement for each process.
Should be a string in the format integer-unit. eg. `--max_cpus 1`

### `--plaintext_email`
Set to receive plain-text e-mails instead of HTML formatted.

### `--monochrome_logs`
Set to disable colourful command line output and live life in monochrome.

### `--multiqc_config`
Specify a path to a custom MultiQC configuration file.
