FROM nfcore/base
LABEL authors="Sven Fillinger, Christopher Mohr, Alexander Peltzer" \
      description="Docker image containing all requirements for nf-core/hlatyping pipeline"

COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a
ENV PATH /opt/conda/envs/nf-core-hlatyping-1.1.5/bin:$PATH
