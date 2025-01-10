process SCANPY_SCRUBLET {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.11.0' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/scanpy_scikit-image:b6fd928892eb1ee9':
        'community.wave.seqera.io/library/scanpy_scikit-image:da08bbc13cee72b2' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad
    tuple val(meta), path("*.pkl") , emit: predictions
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    batch_col = task.ext.batch_col ?: "batch"
    template 'scrublet.py'
}
