FROM mambaorg/micromamba:1.5.10-noble

ENV CONDA_OVERRIDE_CUDA=12

COPY --chown=$MAMBA_USER:$MAMBA_USER conda.yml /tmp/conda.yml

RUN micromamba install -y -n base -f /tmp/conda.yml \
    && micromamba install -y -n base conda-forge::procps-ng \
    && micromamba env export --name base --explicit > environment.lock \
    && echo ">> CONDA_LOCK_START" \
    && cat environment.lock \
    && echo "<< CONDA_LOCK_END" \
    && micromamba clean -a -y
USER root

ENV PATH="$MAMBA_ROOT_PREFIX/bin:$PATH"
