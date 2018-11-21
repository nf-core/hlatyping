FROM nfcore/base
LABEL authors="No author provided" \
      description="Docker image containing all requirements for nf-core/hlatyping pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-hlatyping-None/bin:$PATH
