FROM nfcore/base
MAINTAINER Your Name <your.name@gmail.com>
LABEL authors="your.name@gmail.com" \
    description="Docker image containing all requirements for nf-core/example pipeline"

COPY environment.yml /
RUN conda env update -n root -f /environment.yml && conda clean -a
