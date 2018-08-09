FROM nfcore/base
LABEL description="Docker image containing all requirements for hlatyping pipeline"

COPY environment.yml /
RUN conda env update -n root -f /environment.yml && conda clean -a
