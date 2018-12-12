From:nfcore/base
Bootstrap:docker

%labels
    MAINTAINER No author provided
    DESCRIPTION Singularity image containing all requirements for the nf-core/hlatyping pipeline
    VERSION 1.1.2

%environment
    PATH=/opt/conda/envs/nf-core-hlatyping-1.1.2/bin:$PATH
    export PATH

%files
    environment.yml /

%post
    /opt/conda/bin/conda env create -f /environment.yml
    /opt/conda/bin/conda clean -a
