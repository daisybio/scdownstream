process ADATA_READCSV {
    tag "$meta.id"
    label 'process_single'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/anndata:0.11.1--426fb199a9be8838':
        'community.wave.seqera.io/library/anndata:0.11.1--75463acd25743929' }"

    input:
    tuple val(meta), path(csv)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'readcsv.py'
}
