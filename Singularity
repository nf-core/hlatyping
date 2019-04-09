From:nfcore/base
Bootstrap:docker

%labels
    MAINTAINER Sven Fillinger <sven.fillinger@qbic.uni-tuebingen.de>
    DESCRIPTION Singularity image containing all requirements for nf-core/hlatyping pipeline
    VERSION 1.1.5

%files
    environment.yml /

%post
    /opt/conda/bin/conda env create -f /environment.yml
    /opt/conda/bin/conda clean -a
    PATH=/opt/conda/envs/nf-core-hlatyping-1.1.4/bin:$PATH
    export PATH

    
