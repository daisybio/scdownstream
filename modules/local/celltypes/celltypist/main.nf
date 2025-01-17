process CELLTYPES_CELLTYPIST {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/celltypist_scanpy:89a98f51262cfff4':
        'community.wave.seqera.io/library/celltypist_scanpy:44b604b24dd4cf33' }"

    input:
    tuple val(meta), path(h5ad)
    val(models)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad
    path "*.pkl"                   , emit: obs
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'celltypist.py'
}
