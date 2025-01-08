process SEURAT_INTEGRATION {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bioconductor-glmgampoi_bioconductor-singlecellexperiment_r-seurat:9f31f8040ed0996a':
        'community.wave.seqera.io/library/bioconductor-glmgampoi_bioconductor-singlecellexperiment_r-seurat:379d40215d028661' }"

    input:
    tuple val(meta), path(rds)

    output:
    tuple val(meta), path("*.rds"), emit: rds
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'integration.R'
}
