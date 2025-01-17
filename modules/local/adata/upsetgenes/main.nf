process ADATA_UPSETGENES {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/scanpy_upsetplot:962fb86ff4f03aa4':
        'community.wave.seqera.io/library/scanpy_upsetplot:1ce883f3ff369ca8' }"

    input:
    tuple val(meta), path(h5ad)

    output:
    tuple val(meta), path("*.png"), emit: plot, optional: true
    path("*_mqc.json")            , emit: multiqc_files, optional: true
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix    = task.ext.prefix    ?: "${meta.id}"
    split_col = task.ext.split_col ?: 'sample'
    template 'upsetplot.py'
}
