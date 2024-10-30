process SEACELLS {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/environment.yml"
    container "${ task.ext.use_gpu ? 'ghcr.io/scverse/rapids_singlecell:v0.10.8' :
        workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'oras://community.wave.seqera.io/library/seacells_scanpy:006f252f2ee88c7f':
        'community.wave.seqera.io/library/seacells_scanpy:f2dcd454b4e2474a' }"

    input:
    tuple val(meta), path(h5ad)
    path(json)

    output:
    path("*_sub.h5ad")             , emit: subh5ad
    tuple val(meta), path("${prefix}.h5ad"), emit: h5ad
    path "*.pkl"                   , emit: obs

    //path "*.png"                   , emit: plots
    
    //path "*_mqc.json"              , emit: multiqc_files
    path "versions.yml"            , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    prefix = task.ext.prefix ?: "${meta.id}"
    n_waypoint_eigs = task.ext.n_waypoint_eigs ?: 10 
    max_iterations = task.ext.max_iterations ?: 500
    convergence_epsilon = task.ext.convergence_epsilon ?: 1e-5 
    template 'seacells.py'
}
