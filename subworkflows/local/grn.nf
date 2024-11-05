include { CHECK_SPLIT_CONFIG } from '../../modules/local/grn/check_split_config'
include { ADATA_TORDS } from '../../modules/local/adata/tords'

include { SEACELLS } from '../../modules/local/metacells/seacells'

include { GRNBOOST2 } from '../../modules/local/grn/grnboost2'
include { ZSCORES } from '../../modules/local/grn/zscores'

workflow GRN {
    take:
    ch_h5ad // channel: [ val(meta), path(h5ad) ]

    main:
    ch_versions = Channel.empty()

    if (params.grn_methods == 'none') {
        log.info "GRN: Not performed since 'none' selected."
    } else {

        // Read in json config
        CHECK_SPLIT_CONFIG(ch_h5ad, Channel.fromPath(params.split_config, checkIfExists: true))
        ch_version = ch_versions.mix(CHECK_SPLIT_CONFIG.out.versions)
        ch_splits = CHECK_SPLIT_CONFIG.out.split_config.splitJson().map(
            it -> [it['key'], groovy.json.JsonOutput.prettyPrint(groovy.json.JsonOutput.toJson(it))]
        ).collectFile{
            item -> [ "${item[0]}.json", item[1]]
        }
        
        if (params.metacell_method == 'seacells'){
            SEACELLS(ch_h5ad.combine(ch_splits))
            ch_versions = ch_versions.mix(SEACELLS.out.versions)
            ch_metacells = SEACELLS.out.subh5ad
            // ch_metacells.view()
        } else {
            ch_metacells = ch_h5ad
            log.info "PseudoBulk method is not implemented."
            // TODO: Add error handling
        }

        methods = params.grn_methods.split(',').collect{it.trim().toLowerCase()}

        ch_grn_input = ch_metacells.transpose().map{ id, h5ad -> [[id: id], h5ad]}
        ch_dgrn_input = ch_grn_input.groupTuple(size: 2)
        if (methods.contains('zscores') || methods.contains('diffcoex')) {
            ADATA_TORDS(ch_grn_input.map{ id, h5ad -> [[id: h5ad.baseName, split_config_id: id], h5ad] })
            ch_versions = ch_versions.mix(ADATA_TORDS.out.versions)
            ch_grn_rds_input = ADATA_TORDS.out.rds.map{ meta, rds -> [meta.split_config_id, rds]}
            ch_dgrn_rds_input = ch_grn_rds_input.groupTuple(size: 2)
        }

        ch_grn_results = Channel.empty()
        ch_dgrn_results = Channel.empty()

        if (methods.contains('boostdiff')) {
            BOOSTDIFF(ch_dgrn_input)
            ch_versions = ch_versions.mix(BOOSTDIFF.out.versions)
            ch_dgrn_results = ch_dgrn_results.mix(BOOSTDIFF.out.grn_results)
        }

        if (methods.contains('zscores')) {            
            ZSCORES(ch_dgrn_rds_input)
            ch_versions = ch_versions.mix(ZSCORES.out.versions)
            ch_dgrn_results = ch_dgrn_results.mix(ZSCORES.out.dgrn_results)
        }

        if (methods.contains('diffcoex')) {
            DIFFCOEX(ch_dgrn_rds_input)
            ch_versions = ch_versions.mix(DIFFCOEX.out.versions)
            ch_dgrn_results = ch_dgrn_results.mix(DIFFCOEX.out.grn_results)
        }

        if (methods.contains('grnboost2')) {
            GRNBOOST2(ch_grn_input)
            ch_versions = ch_versions.mix(GRNBOOST2.out.versions)
            ch_grn_results = ch_grn_results.mix(GRNBOOST2.out.grn_results)
        }

        // ch_grn_results.view()
    }

    
    emit:
    versions = ch_versions
}