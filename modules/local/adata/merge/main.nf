process ADATA_MERGE {
    tag "$meta.id"
    label 'process_medium'
    label 'process_high_memory'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/scanpy:1.10.1--ea08051addf267ac':
        'community.wave.seqera.io/library/scanpy:1.10.1--0c8c97148fc05558' }"

    input:
    tuple val(meta),  path(h5ads)
    tuple val(meta2), path(base)

    output:
    tuple val(meta), path("*_outer.h5ad")    , emit: outer
    tuple val(meta), path("*_inner.h5ad")    , emit: inner
    tuple val(meta), path("*_integrate.h5ad"), emit: integrate
    path "gene_intersection.pkl"             , emit: intersect_genes
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    force_obs_cols = task.ext.force_obs_cols ?: params.force_obs_cols ?: ""
    template 'merge.py'
}
