process ADATA_TORDS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/anndata2ri_bioconductor-singlecellexperiment_anndata_r-seurat:c4b75a61a89ec006':
        'community.wave.seqera.io/library/anndata2ri_bioconductor-singlecellexperiment_anndata_r-seurat:5fae42aabf7a1c5f' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.rds"), emit: rds
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    counts_layer = task.ext.counts_layer ?: 'X'
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'tords.py'
}
