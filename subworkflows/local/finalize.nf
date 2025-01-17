include { ADATA_EXTEND        } from '../../modules/local/adata/extend'
include { ADATA_TORDS         } from '../../modules/local/adata/tords'
include { ADATA_PREPCELLXGENE } from '../../modules/local/adata/prepcellxgene'

workflow FINALIZE {
    take:
    ch_h5ad
    ch_obs
    ch_var
    ch_obsm
    ch_obsp
    ch_uns
    ch_layers

    main:
    ch_versions = Channel.empty()

    ADATA_EXTEND(ch_h5ad,
        ch_obs.flatten().collect().ifEmpty([]),
        ch_var.flatten().collect().ifEmpty([]),
        ch_obsm.flatten().collect().ifEmpty([]),
        ch_obsp.flatten().collect().ifEmpty([]),
        ch_uns.flatten().collect().ifEmpty([]),
        ch_layers.flatten().collect().ifEmpty([]))
    ch_versions = ch_versions.mix(ADATA_EXTEND.out.versions)

    ADATA_TORDS(ADATA_EXTEND.out.h5ad)
    ch_versions = ch_versions.mix(ADATA_TORDS.out.versions)

    if (params.prep_cellxgene) {
        ADATA_PREPCELLXGENE(ADATA_EXTEND.out.h5ad)
        ch_versions = ch_versions.mix(ADATA_PREPCELLXGENE.out.versions)
    }

    emit:
    versions = ch_versions
}
