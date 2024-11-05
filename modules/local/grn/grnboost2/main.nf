process GRNBOOST2 {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.10.8' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/python_abi_pip_arboreto_dask-expr_pruned:127355b561af15e8':
        'community.wave.seqera.io/library/python_abi_pip_arboreto_dask-expr_pruned:b71f012d36a48295' }"

    input:
    tuple val(meta), path(sample_h5ad)

    output:
    path "*.csv"                   , emit: grn_results
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    layer = task.ext.layer ?: "raw"
    preprocess_data = task.ext.args ?: ""
    memory_per_worker = task.memory / (task.cpus) 
    template 'grnboost2.py'
}
