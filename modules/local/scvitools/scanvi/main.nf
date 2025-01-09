process SCVITOOLS_SCANVI {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'docker.io/nicotru/scvitools-gpu:1.2.2' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/anndata_scvi-tools:27bf1effeac7f96c':
        'community.wave.seqera.io/library/anndata_scvi-tools:ffa9ea8d87e194a8' }"

    input:
    tuple val(meta), path(h5ad)
    tuple val(meta2), path(reference_model, stageAs: 'reference_model/model.pt')

    output:
    tuple val(meta), path("${prefix}.h5ad")          , emit: h5ad
    tuple val(meta), path("${prefix}_model/model.pt"), emit: model
    path "${prefix}.pkl"                             , emit: obs
    path "X_${prefix}.pkl"                           , emit: obsm
    path "versions.yml"                              , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    n_hidden = task.ext.n_hidden ?: 128
    n_layers = task.ext.n_layers ?: 2
    n_latent = task.ext.n_latent ?: 30
    dispersion = task.ext.dispersion ?: 'gene'
    gene_likelihood = task.ext.gene_likelihood ?: 'zinb'
    max_epochs = task.ext.max_epochs ?: null
    template 'scanvi.py'
}
