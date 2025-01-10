process ADATA_UNIFY {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/mygene_scanpy:fe39686ba0c901e7':
        'community.wave.seqera.io/library/mygene_scanpy:b8864cab99d32be2' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    unify_gene_symbols = task.ext.unify_gene_symbols ?: false
    template 'unify.py'
}
