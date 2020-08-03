# nf-core/hlatyping: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.1.6dev - 2020-08-03

### `Added`

- [#78](https://github.com/nf-core/hlatyping/pull/78) Added GitHub actions instead of Travis CI
- Add social preview image
- [#82](https://github.com/nf-core/hlatyping/pull/82) Updated to nf-core template v1.9

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

Initial release of nf-core/hlatyping, created with the [NGI-NF cookiecutter template](https://github.com/ewels/NGI-NFcookiecutter).

## v1.1.5 - [date]

Initial release of nf-core/hlatyping, created with the [nf-core](http://nf-co.re/) template.
