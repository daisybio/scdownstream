process SCANPY_LEIDEN {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.11.0' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/leidenalg_python-igraph_scanpy:8b9713e90ca62747':
        'community.wave.seqera.io/library/leidenalg_python-igraph_scanpy:270d93d02d764f1a' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad
    path "*.pkl"                   , emit: obs
    path "*.png"                   , emit: plots
    path "*_mqc.json"              , emit: multiqc_files
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    resolution = task.ext.resolution ?: meta.resolution ?: 1.0
    template 'leiden.py'
}
