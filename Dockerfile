
FROM nfcore/base:1.9
LABEL authors="Christopher Mohr, Alexander Peltzer, Sven Fillinger" \
      description="Docker image containing all software requirements for the nf-core/hlatyping pipeline"

# Install the conda environment
COPY environment.yml /
RUN conda env create -f /environment.yml && conda clean -a

# Add conda installation dir to PATH (instead of doing 'conda activate')
ENV PATH /opt/conda/envs/nf-core-hlatyping-1.1.5/bin:$PATH

# Dump the details of the installed packages to a file for posterity
RUN conda env export --name nf-core-hlatyping-1.1.5 > nf-core-hlatyping-1.1.5.yml