process ZSCORES {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/bioconductor-glmgampoi_bioconductor-singlecellexperiment_r-seurat:7a3341fe2726a040':
        'community.wave.seqera.io/library/bioconductor-dcanr_bioconductor-singlecellexperiment_r-igraph_r-seurat_r-tidyverse:5f3657de0088b4d1' }"

    input:
    tuple val(meta), path(sample_rds)

    output:
    path "*.csv"                   , emit: dgrn_results
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    template 'zscores.R'
}
