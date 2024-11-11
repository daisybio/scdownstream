process LIANA_RANKAGGREGATE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/liana:1.4.0--pyhdfd78af_0':
        'biocontainers/liana:1.4.0--pyhdfd78af_0' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.h5ad"), emit: h5ad, optional: true
    path("*.pkl")                  , emit: uns, optional: true
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    obs_key = meta.obs_key ?: "leiden"
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'rank_aggregate.py'
}
