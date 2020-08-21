FROM nfcore/base:1.10.2
LABEL authors="Christopher Mohr, Alexander Peltzer, Sven Fillinger" \
      description="Docker image containing all software requirements for the nf-core/hlatyping pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create --quiet -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-hlatyping-1.2.1dev/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-hlatyping-1.2.1dev > nf-core-hlatyping-1.2.1dev.yml

# Instruct R processes to use these empty files instead of clashing with a local version
RUN touch .Rprofile
RUN touch .Renviron