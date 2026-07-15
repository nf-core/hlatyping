# nf-core/hlatyping: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 2.3.0dev - [releasename] - [YYYY-MM-DD]

### `Added`

- [#211](https://github.com/nf-core/hlatyping/pull/211) - Add HLA\*LA as a third HLA typing tool for HLA typing from BAM files (@jonasscheid)
- [#213](https://github.com/nf-core/hlatyping/pull/213) - Add metro map pipeline overview diagram (@jonasscheid)
- [#214](https://github.com/nf-core/hlatyping/pull/214) - Add [Immunotype](https://github.com/AG-Walz/immunotype) support for peptide-based HLA class I typing (@jonasscheid)
- [#219](https://github.com/nf-core/hlatyping/pull/219) - Add SpecHLA as a BAM-only HLA-typing tool (genome-aligned BAM → ExtractHLAread → SpecHLA) (@jonasscheid)
- [#220](https://github.com/nf-core/hlatyping/pull/220) - Add a `SUMMARIZE_TYPING` module that harmonizes all tools' HLA calls into a single `hlatyping_results.tsv` using mhcgnomes (@jonasscheid)
- [#222](https://github.com/nf-core/hlatyping/pull/222) - FASTQ input support for HLA\*LA and SpecHLA via a GRCh38 genome-alignment step (DNA: bwa-mem, RNA: STAR), inlined into the main workflow's GENOME ALIGNMENT section (@jonasscheid)
- [#222](https://github.com/nf-core/hlatyping/pull/222) - Fail fast when HLA\*LA is given a GENCODE/Ensembl-named GRCh38 reference (only UCSC/1000G naming matches its `knownReferences`), with a clear message pointing at a compatible reference (@jonasscheid)

### `Changed`

- [#222](https://github.com/nf-core/hlatyping/pull/222) - Test one tool per CI profile (drop the `test_optitype_spechla`/`test_optitype_hlahd` combination profiles) so no single shard pulls two tool containers; multi-tool coverage moves to `test_full` (@jonasscheid)
- [#222](https://github.com/nf-core/hlatyping/pull/222) - `test_full` now exercises all public tools (OptiType, SpecHLA, HLA\*LA via GRCh38 alignment, immunotype) on UCSC hg38, over real NA12878 WES and matched GM12878 RNA; OptiType gets 96 GB there because its ILP peaks at 68 GB on full-depth RNA. HLA-HD stays in its dedicated licensed job (@jonasscheid)
- [#211](https://github.com/nf-core/hlatyping/pull/211) - Replace local HLA\*LA modules with nf-core community modules `hlala/typing`, `hlala/preparegraph`, `wget`, and `untar`; checksum validation moved to the workflow (@jonasscheid)
- [#211](https://github.com/nf-core/hlatyping/pull/211) - Clean up published output by disabling publishing for intermediate processes (CHECK_PAIRED, YARA_INDEX, YARA_MAPPER, SAMTOOLS_VIEW, SAMTOOLS_COLLATEFASTQ, HLAHD_INSTALL, WGET, UNTAR, HLALA_PREPAREGRAPH) (@jonasscheid)
- [#218](https://github.com/nf-core/hlatyping/pull/218) - Merge nf-core template updates up to `4.0.2` (@jonasscheid)
- [#221](https://github.com/nf-core/hlatyping/pull/221) - Update the metro map overview diagram to include HLA\*LA, SpecHLA, immunotype (TSV input) and the summary step, with animated lines, regenerated using nf-metro 0.7.2 (@jonasscheid)

### `Fixed`

- [#212](https://github.com/nf-core/hlatyping/pull/212) - Fix nextflow lint errors and warnings (@jonasscheid)

### `Dependencies`

| Dependency   | Old version | New version |
| ------------ | ----------- | ----------- |
| `HLA*LA`     | -           | 1.0.4       |
| `Immunotype` | -           | 1.0.2       |
| `SpecHLA`    | -           | 1.0.12      |
| `bwa`        | -           | 0.7.19      |
| `STAR`       | -           | 2.7.11b     |
| `MultiQC`    | 1.32        | 1.34        |
| `samtools`   | 1.21        | 1.23.1      |
| `nf-core`    | 3.5.1       | 4.0.2       |
| `mhcgnomes`  | -           | 1.8.6       |
| `Nextflow`   | 25.04.2     | 25.10.4     |

## 2.2.0 - Holocron - 2026-01-28

### `Added`

- [#201](https://github.com/nf-core/hlatyping/pull/201) - Option to run HLA-HD (v1.7.1) for Class I and Class II HLA typing (@riederd)
- [#204](https://github.com/nf-core/hlatyping/pull/204) - CI tests for HLA-HD using encrypted licensed software, following nf-core external tool pattern (@jonasscheid)

### `Changed`

- [#202](https://github.com/nf-core/hlatyping/pull/202) - Merge nf-core template updates up to `3.5.1` (@jonasscheid)

### `Fixed`

- [#207](https://github.com/nf-core/hlatyping/pull/207) - Fix conda tests by updating Nextflow to 25.04.2 (@jonasscheid)
- [#208](https://github.com/nf-core/hlatyping/pull/208) - Fix conda tests by pinning pytables<3.10 (@jonasscheid)

### `Dependencies`

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| `HLA-HD`   | -           | 1.7.1       |
| `MultiQC`  | 1.27.0      | 1.33.0      |
| `nf-core`  | 3.2.0       | 3.5.1       |
| `Nextflow` | 24.04.2     | 25.04.2     |

## 2.1.0 - Patch Release - 2025-11-04

### `Added`

- [#169](https://github.com/nf-core/hlatyping/pull/169) - Parameter `enumerations` to specify the number of solutions provided by Optitype
- [#179](https://github.com/nf-core/hlatyping/pull/179) - Add merging of resequenced fastq files

### `Changed`

- [#152](https://github.com/nf-core/hlatyping/pull/152) - Merge nf-core template updates up to `2.7.2`
- [#165](https://github.com/nf-core/hlatyping/pull/165) - Merge nf-core template updates up to `2.13.1`
- [#181](https://github.com/nf-core/hlatyping/pull/181) - Merge nf-core template updates up to `3.2`
- [#189](https://github.com/nf-core/hlatyping/pull/189) - Update nf-core modules

### `Fixed`

### `Dependencies`

### `Deprecated`

## 2.0.0 - Han Solo - 2022-10-18

### `Added`

- [#141](https://github.com/nf-core/hlatyping/pull/141) - Add `OptiType` results to `MultiQC` report

### `Changed`

- [#140](https://github.com/nf-core/hlatyping/pull/140) - Port pipeline to `DSL2`
- [#140](https://github.com/nf-core/hlatyping/pull/140) - Merge nf-core template updates up to `2.6`
- [#140](https://github.com/nf-core/hlatyping/pull/140) - Support for BAM and FASTQ input in the same run
- [#140](https://github.com/nf-core/hlatyping/pull/140) - Support for DNA and RNA input in the same run

### `Fixed`

### `Dependencies`

### `Deprecated`

## 1.2.0 - lead-sparrow - 2020-08-21

### `Added`

- [#91](https://github.com/nf-core/hlatyping/pull/91) - Add pipeline parameter schema
- [#78](https://github.com/nf-core/hlatyping/pull/78) - Add GitHub actions instead of Travis CI
- [#73](https://github.com/nf-core/hlatyping/pull/73) - Add social preview image

### `Changed`

- [#84](https://github.com/nf-core/hlatyping/pull/84), [#91](https://github.com/nf-core/hlatyping/pull/91) - Change input parameters (`--input` instead of `--reads`, the parameters `--genome` and `--fasta` are deprecated for this pipeline)
- [#89](https://github.com/nf-core/hlatyping/pull/89), [#90](https://github.com/nf-core/hlatyping/pull/90) - Update to nf-core template v1.10.2
- [#81](https://github.com/nf-core/hlatyping/pull/81), [#82](https://github.com/nf-core/hlatyping/pull/82) - Update to nf-core template v1.9

### `Fixed`

- [#79](https://github.com/nf-core/hlatyping/pull/79) - Fix mapping index issue [#68](https://github.com/nf-core/hlatyping/issues/68)

## 1.1.5 - Patch release - 2019-06-24

- Mini Bugfix Release for MultiQC running in local execution mode

## 1.1.4 - Patch release - 2019-03-06

- Fix issues with [centralized configs](https://github.com/nf-core/hlatyping/issues/51)
- Fix with pandas, pinning to numpy 1.15.4 instead of 1.16.0

## 1.1.3 - Patch release - 2019-02-04

- Multiple smaller bugfixes, cleaned up code basis
- [#48](https://github.com/nf-core/hlatyping/issues/48) - Utilizes RNA/DNA reference genome for remapping correctly

## 1.1.2 - Patch release - 2018-12-12

- Fix [#37](https://github.com/nf-core/hlatyping/issues/37)

## 1.1.1 - Patch release - 2018-08-21

- Fix [#30](https://github.com/nf-core/hlatyping/issues/30)
- Removed support to pull from Singularity Hub directly, when using the profile `singularity`. For now, Nextflow will pull the container image from Docker Hub and create the Singularity container on the local host.

## 1.1.0 - aqua-titanium-crab - 2018-08-14

- Fix [#17](https://github.com/nf-core/hlatyping/issues/17)
- Fix [#13](https://github.com/nf-core/hlatyping/issues/13)
- Fix [#12](https://github.com/nf-core/hlatyping/issues/12)
- New profile `full_trace` that can be used for full trace info broadcast with Nextflow's `weblog feature`
- New profile `cfc` with setups for the core facility cluster at QBiC

## 1.0.0 - 2018-07-17

# Initial release of nf-core/hlatyping, created with the [NGI-NF cookiecutter template](https://github.com/ewels/NGI-NFcookiecutter)
