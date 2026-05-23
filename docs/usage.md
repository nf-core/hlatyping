# nf-core/hlatyping: Usage

## :warning: Please read this documentation on the nf-core website: [https://nf-co.re/hlatyping/usage](https://nf-co.re/hlatyping/usage)

> _Documentation of pipeline parameters is generated automatically from the pipeline schema and can no longer be found in markdown files._

## Introduction

The `hlatyping` pipeline can currently deal with two input formats: `.fastq{.gz}` or `.bam`. If the input file type is `bam`, than the pipeline extracts all reads from it and performs an mapping additional step with the `yara` mapper against the HLA reference sequence. Indices are generated using `yara`. OptiType uses [razers3](https://github.com/seqan/seqan/tree/master/apps/razers3), which is very memory consuming. In order to avoid memory issues during pipeline execution, we reduce the mapping information on the relevant HLA regions on chromosome 6.

### FASTQ input

When `.fastq{.gz}` files are provided, the pipeline extracts reads and maps them against the HLA reference sequence on chromosome 6 using `yara`. OptiType and/or HLA-HD then perform HLA typing from the mapped reads.

### BAM input

When `.bam` files are provided, the pipeline handles them in two ways depending on the selected tools:

- **OptiType / HLA-HD**: Reads are extracted from the BAM file using `samtools`, converted to FASTQ, and then processed through the standard FASTQ pipeline path.
- **HLA\*LA**: BAM files are used directly. The BAM is re-compressed to BGZF format, indexed, and passed to HLA\*LA along with the graph reference. **Important:** HLA\*LA requires genome-aligned BAM files (e.g., aligned to GRCh38), not HLA-reference-aligned BAMs. FASTQ input is not supported for HLA\*LA.

## Samplesheet input

You will need to create a samplesheet with information about the samples you would like to analyse before running the pipeline. Use this parameter to specify its location. It has to be a comma-separated file with 4 columns, and a header row as shown in the examples below.

```bash
--input '[path to samplesheet file]'
```

### Multiple runs of the same sample

The `sample` identifiers have to be the same when you have re-sequenced the same sample more than once e.g. to increase sequencing depth. The pipeline will concatenate the raw reads before performing any downstream analysis. Below is an example for the same sample sequenced across 3 lanes. Concatenation is only supported for `fastq` files, not `BAM` files.

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,seq_type
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,rna
CONTROL_REP1,AEG588A1_S1_L003_R1_001.fastq.gz,AEG588A1_S1_L003_R2_001.fastq.gz,rna
CONTROL_REP1,AEG588A1_S1_L004_R1_001.fastq.gz,AEG588A1_S1_L004_R2_001.fastq.gz,rna
```

### Full samplesheet

The pipeline will auto-detect whether a sample is single- or paired-end using the information provided in the samplesheet. The samplesheet can have as many columns as you desire, however, there is a strict requirement for the first 4 columns to match those defined in the table below.

A final samplesheet file consisting of both single- and paired-end data may look something like the one below.

```csv title="samplesheet.csv"
sample,fastq_1,fastq_2,seq_type
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,dna
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz,dna
CONTROL_REP3,AEG588A3_S3_L002_R1_001.fastq.gz,AEG588A3_S3_L002_R2_001.fastq.gz,dna
TREATMENT_REP1,AEG588A4_S4_L003_R1_001.fastq.gz,,dna
TREATMENT_REP2,AEG588A5_S5_L003_R1_001.fastq.gz,,dna
TREATMENT_REP3,AEG588A6_S6_L003_R1_001.fastq.gz,,dna
TREATMENT_REP3,AEG588A6_S6_L004_R1_001.fastq.gz,,dna
```

The pipeline can also process `BAM` files. If you want to process a `BAM` file, just add the corresponding column to the samplesheet and provide the full path to the file. `FASTQ` and `BAM` files can be mixed in the same sample sheet.

```console
sample,fastq_1,fastq_2,bam,seq_type
CONTROL_REP1,AEG588A1_S1_L002_R1_001.fastq.gz,AEG588A1_S1_L002_R2_001.fastq.gz,,dna
CONTROL_REP2,AEG588A2_S2_L002_R1_001.fastq.gz,AEG588A2_S2_L002_R2_001.fastq.gz,,rna
TREATMENT_REP1,,,AEG588A4_S4_L003_R1_001.bam,dna
```

Peptide TSV input is also supported for Immunotype (selected via `--tools immunotype`). Rows set `seq_type` to `peptide` and use the `tsv` column instead of `fastq_*`/`bam`:

```console
sample,tsv,seq_type
HepG2_A,HepG2_A.tsv,peptide
```

| Column     | Description                                                                                                                |
| ---------- | -------------------------------------------------------------------------------------------------------------------------- |
| `sample`   | Custom sample name.                                                                                                        |
| `fastq_1`  | Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz". |
| `fastq_2`  | Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension ".fastq.gz" or ".fq.gz". |
| `bam`      | OPTIONAL. Full path to BAM file.                                                                                           |
| `tsv`      | OPTIONAL. Full path to a peptide TSV (used with `seq_type: peptide` for Immunotype).                                       |
| `seq_type` | `DNA`, `RNA`, or `peptide`.                                                                                                |

Each row must provide exactly one of `fastq_1`, `bam`, or `tsv`. By default the `tsv` file is assumed to have a header with a `sequence` column (MHCquant-style); override with `--peptide_col_name <col>`, or pass a headerless peptide list by setting `peptide_col_name` to `null` via a params file.

An [example samplesheet](../assets/samplesheet.csv) has been provided with the pipeline.

### HLA references

The **nf-core/hlatyping** pipeline ships its HLA references in the pipeline root directory under `./data/references`. OptiType uses `hla_reference_dna.fasta` and `hla_reference_rna.fasta`, selected automatically from the `seq_type` column of the samplesheet (`dna` or `rna`). These are based on the IMGT/HLA Release `3.14.0`, July 2013, and have been processed as described in the [publication](https://doi.org/10.1093/bioinformatics/btu548) of OptiType.

You can always download new versions from the [HLA database](https://www.ebi.ac.uk/ipd/imgt/hla/docs/release.html), but be aware that these allele sets are missing intron sequence information, which will have a negative influence in the HLA typing outcome in case of DNAseq.

We are currently looking into a dynamic solution, in order to build pre-processed input HLA references from current HLA allele information from the IPD-IMGT/HLA database.
If you wish to repeatedly use the same parameters for multiple runs, rather than specifying each flag in the command, you can specify these in a params file.

### HLA typing tools

The pipeline supports four HLA typing tools, controlled by the `--tools` parameter:

- **OptiType** (default): HLA Class I typing from FASTQ or BAM input. Open-source, included in pipeline containers.
- **HLA-HD**: HLA Class I + II typing from FASTQ or BAM input. Requires a local installation due to licensing restrictions (see [HLA-HD section](#hla-hd-setup)).
- **HLA\*LA**: HLA typing from BAM input only. Open-source, included in pipeline containers. Uses a graph-based approach with the PRG_MHC_GRCh38_withIMGT reference graph.
- **SpecHLA**: Full-resolution HLA Class I + II typing from a genome-aligned BAM input (BAM only). Open-source, included in pipeline containers (see [SpecHLA notes](#spechla)).

Tools can be combined:

```bash
--tools optitype,hlala      # Run both OptiType and HLA*LA (BAM input required)
--tools optitype,hlahd      # Run both OptiType and HLA-HD
--tools optitype,spechla    # Run both OptiType and SpecHLA
```

> [!NOTE]
> HLA\*LA requires genome-aligned BAM input (e.g., aligned to GRCh38). Unlike OptiType and HLA-HD, it cannot work from FASTQ files or HLA-reference-aligned BAMs. If you specify `--tools hlala` with FASTQ-only samples, HLA\*LA will not run for those samples.

### HLA\*LA setup

HLA\*LA requires a graph reference (~5 GB) which can be provided in three ways:

1. **Automatic download** (default): The graph is downloaded from a [Zenodo mirror](https://zenodo.org/records/19336310) during the pipeline run.
2. **Pre-downloaded tarball**: Provide the path to a downloaded `PRG_MHC_GRCh38_withIMGT.tar.gz` tarball:
   ```bash
   --hlala_graph_tarball /path/to/PRG_MHC_GRCh38_withIMGT.tar.gz
   ```
3. **Pre-built graph directory**: Provide the parent directory containing the extracted graph:
   ```bash
   --hlala_graph_dir /path/to/graphs/
   ```
   The directory should contain the `PRG_MHC_GRCh38_withIMGT/` subdirectory.

### HLA-HD setup

HLA-HD is not distributed with the pipeline's containers due to licensing restrictions. The software is freely available for academic and non-commercial research. Users must register and download it from the [HLA-HD website](https://w3.genome.med.kyoto-u.ac.jp/HLA-HD/). Provide the path to the downloaded tarball:

```bash
--tools hlahd --hlahd_path /path/to/hlahd.1.7.1.tar.gz
```

### SpecHLA

SpecHLA performs HLA typing for Class I and Class II across 8 loci. See the [SpecHLA documentation](https://github.com/deepomicslab/SpecHLA) for tool-specific details.

In nf-core/hlatyping it is **BAM-only**: `--tools spechla` requires a coordinate-sorted, genome-aligned BAM (hg38 by default) as input — FASTQ samples are rejected at parameter validation. The pipeline runs SpecHLA's own `ExtractHLAread` step to pull HLA reads from the BAM before typing.

- For BAMs aligned to hg19, override the reference build:
  ```nextflow
  process { withName: SPECHLA_EXTRACT { ext.args = '-r hg19' } }
  ```
- Typing mode (`-u`) and population prior (`-p`) default to `-u 1 -p nonuse` (exon typing, ancestry-neutral). `-u`: `0` = full-length, `1` = exon. `-p`: `Asian | Black | Caucasian | Unknown | nonuse`. Override via `ext.args`:
  ```nextflow
  process {
      withName: SPECHLA_TYPING {
          ext.args = '-u 0 -p nonuse'
      }
  }
  ```

## Running the pipeline

The typical command for running the pipeline is as follows:

```bash
nextflow run nf-core/hlatyping --input ./samplesheet.csv --outdir ./results -profile docker
```

This will launch the pipeline with the `docker` configuration profile. See below for more information about profiles.

Note that the pipeline will create the following files in your working directory:

```bash
work                # Directory containing the nextflow working files
<OUTDIR>            # Finished results in specified location (defined with --outdir)
.nextflow_log       # Log file from Nextflow
# Other nextflow hidden files, eg. history of pipeline runs and old logs.
```

Pipeline settings can be provided in a `yaml` or `json` file via `-params-file <file>`.

> [!WARNING]
> Do not use `-c <file>` to specify parameters as this will result in errors. Custom config files specified with `-c` must only be used for [tuning process resource specifications](https://nf-co.re/docs/running/run-pipelines#configuring-pipelines), other infrastructural tweaks (such as output directories), or module arguments (args).

The above pipeline run specified with a params file in yaml format:

```bash
nextflow run nf-core/hlatyping -profile docker -params-file params.yaml
```

with:

```yaml title="params.yaml"
input: './samplesheet.csv'
outdir: './results/'
genome: 'GRCh37'
<...>
```

You can also generate such `YAML`/`JSON` files via [nf-core/launch](https://nf-co.re/launch).

### Updating the pipeline

When you run the above command, Nextflow automatically pulls the pipeline code from GitHub and stores it as a cached version. When running the pipeline after this, it will always use the cached version if available - even if the pipeline has been updated since. To make sure that you're running the latest version of the pipeline, make sure that you regularly update the cached version of the pipeline:

```bash
nextflow pull nf-core/hlatyping
```

### Reproducibility

It is a good idea to specify the pipeline version when running the pipeline on your data. This ensures that a specific version of the pipeline code and software are used when you run your pipeline. If you keep using the same tag, you'll be running the same version of the pipeline, even if there have been changes to the code since.

First, go to the [nf-core/hlatyping releases page](https://github.com/nf-core/hlatyping/releases) and find the latest pipeline version - numeric only (eg. `1.3.1`). Then specify this when running the pipeline with `-r` (one hyphen) - eg. `-r 1.3.1`. Of course, you can switch to another version by changing the number after the `-r` flag.

This version number will be logged in reports when you run the pipeline, so that you'll know what you used when you look back in the future. For example, at the bottom of the MultiQC reports.

To further assist in reproducibility, you can use share and reuse [parameter files](#running-the-pipeline) to repeat pipeline runs with the same settings without having to write out a command with every single parameter.

> [!TIP]
> If you wish to share such profile (such as upload as supplementary material for academic publications), make sure to NOT include cluster specific paths to files, nor institutional specific profiles.

## Core Nextflow arguments

> [!NOTE]
> These options are part of Nextflow and use a _single_ hyphen (pipeline parameters use a double-hyphen)

### `-profile`

Use this parameter to choose a configuration profile. Profiles can give configuration presets for different compute environments.

Several generic profiles are bundled with the pipeline which instruct the pipeline to use software packaged using different methods (Docker, Singularity, Podman, Shifter, Charliecloud, Apptainer, Conda) - see below.

> [!IMPORTANT]
> We highly recommend the use of Docker or Singularity containers for full pipeline reproducibility, however when this is not possible, Conda is also supported.

The pipeline also dynamically loads configurations from [https://github.com/nf-core/configs](https://github.com/nf-core/configs) when it runs, making multiple config profiles for various institutional clusters available at run time. For more information and to check if your system is supported, please see the [nf-core/configs documentation](https://github.com/nf-core/configs#documentation).

Note that multiple profiles can be loaded, for example: `-profile test,docker` - the order of arguments is important!
They are loaded in sequence, so later profiles can overwrite earlier profiles.

If `-profile` is not specified, the pipeline will run locally and expect all software to be installed and available on the `PATH`. This is _not_ recommended, since it can lead to different results on different machines dependent on the computer environment.

- `test`
  - A profile with a complete configuration for automated testing
  - Includes links to test data so needs no other parameters
- `docker`
  - A generic configuration profile to be used with [Docker](https://docker.com/)
- `singularity`
  - A generic configuration profile to be used with [Singularity](https://sylabs.io/docs/)
- `podman`
  - A generic configuration profile to be used with [Podman](https://podman.io/)
- `shifter`
  - A generic configuration profile to be used with [Shifter](https://nersc.gitlab.io/development/shifter/how-to-use/)
- `charliecloud`
  - A generic configuration profile to be used with [Charliecloud](https://charliecloud.io/)
- `apptainer`
  - A generic configuration profile to be used with [Apptainer](https://apptainer.org/)
- `wave`
  - A generic configuration profile to enable [Wave](https://seqera.io/wave/) containers. Use together with one of the above (requires Nextflow ` 24.03.0-edge` or later).
- `conda`
  - A generic configuration profile to be used with [Conda](https://conda.io/docs/). Please only use Conda as a last resort i.e. when it's not possible to run the pipeline with Docker, Singularity, Podman, Shifter, Charliecloud, or Apptainer.

### `-resume`

Specify this when restarting a pipeline. Nextflow will use cached results from any pipeline steps where the inputs are the same, continuing from where it got to previously. For input to be considered the same, not only the names must be identical but the files' contents as well. For more info about this parameter, see [this blog post](https://www.nextflow.io/blog/2019/demystifying-nextflow-resume.html).

You can also supply a run name to resume a specific run: `-resume [run-name]`. Use the `nextflow log` command to show previous run names.

### `-c`

Specify the path to a specific config file (this is a core Nextflow command). See the [nf-core website documentation](https://nf-co.re/usage/configuration) for more information.

## Custom configuration

### Resource requests

Whilst the default requirements set within the pipeline will hopefully work for most people and with most input data, you may find that you want to customise the compute resources that the pipeline requests. Each step in the pipeline has a default set of requirements for number of CPUs, memory and time. For most of the pipeline steps, if the job exits with any of the error codes specified [here](https://github.com/nf-core/rnaseq/blob/4c27ef5610c87db00c3c5a3eed10b1d161abf575/conf/base.config#L18) it will automatically be resubmitted with higher resources request (2 x original, then 3 x original). If it still fails after the third attempt then the pipeline execution is stopped.

To change the resource requests, please see the [max resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#set-max-resources) and [customise process resources](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#customize-process-resources) section of the nf-core website.

### Custom Containers

In some cases, you may wish to change the container or conda environment used by a pipeline steps for a particular tool. By default, nf-core pipelines use containers and software from the [biocontainers](https://biocontainers.pro/) or [bioconda](https://bioconda.github.io/) projects. However, in some cases the pipeline specified version maybe out of date.

To use a different container from the default container or conda environment specified in a pipeline, please see the [updating tool versions](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#update-tool-versions) section of the nf-core website.

### Custom Tool Arguments

A pipeline might not always support every possible argument or option of a particular tool used in pipeline. Fortunately, nf-core pipelines provide some freedom to users to insert additional parameters that the pipeline does not include by default.

To learn how to provide additional arguments to a particular tool of the pipeline, please see the [customising tool arguments](https://nf-co.re/docs/running/configuration/nextflow-for-your-system#modifying-tool-arguments) section of the nf-core website.

### nf-core/configs

In most cases, you will only need to create a custom config as a one-off but if you and others within your organisation are likely to be running nf-core pipelines regularly and need to use the same settings regularly it may be a good idea to request that your custom config file is uploaded to the `nf-core/configs` git repository. Before you do this please can you test that the config file works with your pipeline of choice using the `-c` parameter. You can then create a pull request to the `nf-core/configs` repository with the addition of your config file, associated documentation file (see examples in [`nf-core/configs/docs`](https://github.com/nf-core/configs/tree/master/docs)), and amending [`nfcore_custom.config`](https://github.com/nf-core/configs/blob/master/nfcore_custom.config) to include your custom profile.

See the main [Nextflow documentation](https://www.nextflow.io/docs/latest/config.html) for more information about creating your own configuration files.

If you have any questions or issues please send us a message on [Slack](https://nf-co.re/join/slack) on the [`#configs` channel](https://nfcore.slack.com/channels/configs).

## Running in the background

Nextflow handles job submissions and supervises the running jobs. The Nextflow process must run until the pipeline is finished.

The Nextflow `-bg` flag launches Nextflow in the background, detached from your terminal so that the workflow does not stop if you log out of your session. The logs are saved to a file.

Alternatively, you can use `screen` / `tmux` or similar tool to create a detached session which you can log back into at a later time.
Some HPC setups also allow you to run nextflow within a cluster job submitted your job scheduler (from where it submits more jobs).

## Nextflow memory requirements

In some cases, the Nextflow Java virtual machines can start to request a large amount of memory.
We recommend adding the following line to your environment to limit this (typically in `~/.bashrc` or `~./bash_profile`):

```bash
NXF_OPTS='-Xms1g -Xmx4g'
```
