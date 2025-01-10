process SCANPY_RANKGENESGROUPS {
    tag "$meta.id"
    label 'process_medium'
    label 'process_gpu'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.11.0' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/scanpy:1.10.4--c2d474f46255931c':
        'community.wave.seqera.io/library/scanpy:1.10.4--f905699eb17b6536' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad, optional: true
    path "*.pkl"                   , emit: uns, optional: true
    path "*.png"                   , emit: plots, optional: true
    path "*_mqc.json"              , emit: multiqc_files, optional: true
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    obs_key = meta.obs_key ?: "leiden"
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'rank_genes_groups.py'
}
