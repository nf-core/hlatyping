FROM nfcore/base
MAINTAINER Sven Fillinger <sven.fillinger@qbic.uni-tuebingen.de>
LABEL authors="sven.fillinger@qbic.uni-tuebingen.de" \
    description="Docker image containing all requirements for nf-core/hlatyping pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-hlatyping-1.2dev/bin:$PATH
