From:nfcore/base
Bootstrap:docker

%labels
    MAINTAINER Sven Fillinger <sven.fillinger@qbic.uni-tuebingen.de>
    DESCRIPTION Singularity image containing all requirements for nf-core/hlatyping pipeline
    VERSION 0.1.0

%files
    environment.yml /

%post
    conda env create -n root -f /environment.yml && conda clean -a