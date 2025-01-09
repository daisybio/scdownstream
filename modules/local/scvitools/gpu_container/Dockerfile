FROM mambaorg/micromamba:2.0.5

ENV CONDA_OVERRIDE_CUDA=12

COPY environment.yml /tmp/environment.yml

RUN micromamba env update -n base -f /tmp/environment.yml
