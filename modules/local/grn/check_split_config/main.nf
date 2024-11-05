process CHECK_SPLIT_CONFIG {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.10.8' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/arboreto_scanpy_pip_dask-expr_distributed:101f9501cacba088':
        'community.wave.seqera.io/library/arboreto_scanpy:66cdfd7cc7d6b5d6' }"

    input:
    tuple val(meta), path(h5ad)
    path(split_config)

    output:
    path "versions.yml"            , emit: versions
    path split_config              , emit: split_config
    
    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'check_split_config.py'
}
