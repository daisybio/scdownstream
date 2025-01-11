process ADATA_MERGEEMBEDDINGS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/scanpy:1.10.4--c2d474f46255931c':
        'community.wave.seqera.io/library/scanpy:1.10.4--f905699eb17b6536' }"

    input:
    tuple val(meta), path(integrated, stageAs: 'integrated.h5ad'), path(base), path(combined)

    output:
    tuple val(meta), path("${prefix}.h5ad"), emit: h5ad
    path("${prefix}.pkl")                  , emit: obs, optional: true
    path("X_${prefix}.pkl")                , emit: obsm
    path "versions.yml"                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'merge_embeddings.py'
}