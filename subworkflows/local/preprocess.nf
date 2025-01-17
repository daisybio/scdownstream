include { SCANPY_READH5                         } from '../../modules/local/scanpy/readh5'
include { ADATA_READRDS                         } from '../../modules/local/adata/readrds'
include { ADATA_READCSV                         } from '../../modules/local/adata/readcsv'
include { EMPTY_DROPLET_REMOVAL                 } from './empty_droplet_removal'
include { ADATA_UNIFY                           } from '../../modules/local/adata/unify'
include { ADATA_GETSIZE as GET_UNFILTERED_SIZE  } from '../../modules/local/adata/getsize'
include { ADATA_GETSIZE as GET_FILTERED_SIZE    } from '../../modules/local/adata/getsize'
include { ADATA_GETSIZE as GET_THRESHOLDED_SIZE } from '../../modules/local/adata/getsize'
include { ADATA_GETSIZE as GET_DEDOUBLETED_SIZE } from '../../modules/local/adata/getsize'
include { SCANPY_PLOTQC as QC_RAW               } from '../../modules/local/scanpy/plotqc'
include { AMBIENT_RNA_REMOVAL                   } from './ambient_rna_removal'
include { SCANPY_FILTER                         } from '../../modules/local/scanpy/filter'
include { DOUBLET_DETECTION                     } from './doublet_detection'
include { SCANPY_PLOTQC as QC_FILTERED          } from '../../modules/local/scanpy/plotqc'
include { CUSTOM_COLLECTSIZES as COLLECT_SIZES  } from '../../modules/local/custom/collectsizes'

workflow PREPROCESS {

    take:
    ch_samples // channel: [ val(meta), file ]

    main:

    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()
    ch_h5ad = Channel.empty()
    ch_files = Channel.empty()
    ch_sizes = Channel.empty()

    ch_files = ch_files.mix(ch_samples
        .map { meta, filtered, unfiltered -> [meta + [type: 'filtered'], filtered] }
        .filter { meta, filtered -> filtered }
    )
    ch_files = ch_files.mix(ch_samples
        .map { meta, filtered, unfiltered -> [meta + [type: 'unfiltered'], unfiltered] }
        .filter { meta, unfiltered -> unfiltered }
    )
    ch_metas = ch_samples.map{ meta, filtered, unfiltered -> meta }

    ch_files = ch_files.map { meta, file -> [meta, file, file.extension.toLowerCase()] }
        .branch { meta, file, ext ->
            unified: ext == "h5ad" && meta.unified == true
                return [meta, file]
            h5ad: ext == "h5ad"
                return [meta, file]
            h5: ext == "h5"
                return [meta, file]
            rds: ext == "rds"
                return [meta, file]
            csv: ext == "csv"
                return [meta, file]
        }

    ch_h5ad = ch_h5ad.mix(ch_files.h5ad)

    SCANPY_READH5(ch_files.h5)
    ch_h5ad = ch_h5ad.mix(SCANPY_READH5.out.h5ad)
    ch_versions = ch_versions.mix(SCANPY_READH5.out.versions)

    ADATA_READRDS(ch_files.rds)
    ch_h5ad = ch_h5ad.mix(ADATA_READRDS.out.h5ad)
    ch_versions = ch_versions.mix(ADATA_READRDS.out.versions)

    ADATA_READCSV(ch_files.csv)
    ch_h5ad = ch_h5ad.mix(ADATA_READCSV.out.h5ad)
    ch_versions = ch_versions.mix(ADATA_READCSV.out.versions)

    ADATA_UNIFY(ch_h5ad)
    ch_h5ad = ADATA_UNIFY.out.h5ad
    ch_versions = ch_versions.mix(ADATA_UNIFY.out.versions)

    GET_UNFILTERED_SIZE(ch_h5ad.filter{ meta, h5ad -> meta.type == 'unfiltered' })
    ch_versions = ch_versions.mix(GET_UNFILTERED_SIZE.out.versions)
    ch_sizes = ch_sizes.mix(GET_UNFILTERED_SIZE.out.txt
        .map{ meta, txt -> [meta.id, 'unfiltered', txt.text.toInteger()] })

    ch_h5ad = ch_h5ad.mix(ch_files.unified)

    ch_samples = ch_metas.map{ meta -> [meta.id, meta]}
            .join(
                ch_h5ad.filter { meta, h5ad -> meta.type == 'filtered' }
                .map{ meta, filtered -> [meta.id, filtered]},
                failOnMismatch: false, remainder: true
            )
            .join(ch_h5ad
                .filter { meta, h5ad -> meta.type == 'unfiltered' }
                .map{ meta, unfiltered -> [meta.id, unfiltered]},
                failOnMismatch: false, remainder: true)
            .map{ id, meta, filtered, unfiltered -> [meta, filtered ?: [], unfiltered ?: []] }
            .branch{ meta, filtered, unfiltered ->
                complete: filtered
                    return [meta, filtered, unfiltered]
                needs_filtering: unfiltered
                    return [meta, filtered, unfiltered]
                problematic: true
                    return [meta, filtered, unfiltered]
            }

    ch_complete = ch_samples.complete
    ch_needs_filtering = ch_samples.needs_filtering

    EMPTY_DROPLET_REMOVAL(ch_needs_filtering.map{ meta, filtered, unfiltered -> [meta, unfiltered] })
    ch_versions = ch_versions.mix(EMPTY_DROPLET_REMOVAL.out.versions)

    ch_complete = ch_complete.mix(ch_needs_filtering
        .join(EMPTY_DROPLET_REMOVAL.out.h5ad)
        .map{ meta, empty, unfiltered, filtered -> [meta, filtered, unfiltered] }
    )

    GET_FILTERED_SIZE(ch_complete.map{ meta, filtered, unfiltered -> [meta, filtered] })
    ch_versions = ch_versions.mix(GET_FILTERED_SIZE.out.versions)
    ch_sizes = ch_sizes.mix(GET_FILTERED_SIZE.out.txt
        .map{ meta, txt -> [meta.id, 'filtered', txt.text.toInteger()] })

    QC_RAW(ch_complete.map{ meta, filtered, unfiltered -> [meta, filtered] })
    ch_multiqc_files = ch_multiqc_files.mix(QC_RAW.out.multiqc_files)
    ch_versions = ch_versions.mix(QC_RAW.out.versions)

    AMBIENT_RNA_REMOVAL(ch_complete)
    ch_h5ad = AMBIENT_RNA_REMOVAL.out.h5ad
    ch_versions = ch_versions.mix(AMBIENT_RNA_REMOVAL.out.versions)

    SCANPY_FILTER(ch_h5ad)
    ch_h5ad = SCANPY_FILTER.out.h5ad
    ch_versions = ch_versions.mix(SCANPY_FILTER.out.versions)

    GET_THRESHOLDED_SIZE(ch_h5ad)
    ch_versions = ch_versions.mix(GET_THRESHOLDED_SIZE.out.versions)
    ch_sizes = ch_sizes.mix(GET_THRESHOLDED_SIZE.out.txt
        .map{ meta, txt -> [meta.id, 'thresholded', txt.text.toInteger()] })

    DOUBLET_DETECTION(ch_h5ad)
    ch_h5ad = DOUBLET_DETECTION.out.h5ad
    ch_multiqc_files = ch_multiqc_files.mix(DOUBLET_DETECTION.out.multiqc_files)
    ch_versions = ch_versions.mix(DOUBLET_DETECTION.out.versions)

    GET_DEDOUBLETED_SIZE(ch_h5ad)
    ch_versions = ch_versions.mix(GET_DEDOUBLETED_SIZE.out.versions)
    ch_sizes = ch_sizes.mix(GET_DEDOUBLETED_SIZE.out.txt
        .map{ meta, txt -> [meta.id, 'dedoubleted', txt.text.toInteger()] })

    QC_FILTERED(ch_h5ad)
    ch_multiqc_files = ch_multiqc_files.mix(QC_FILTERED.out.multiqc_files)
    ch_versions = ch_versions.mix(QC_FILTERED.out.versions)

    ch_sizes = ch_sizes.collectFile(
        seed: "sample\tstate\tsize",
        newLine: true,
        name: "size_list.tsv"
    ){ sample, state, size -> "${sample}\t${state}\t${size}" }
    .map{ file -> [[id: 'sizes'], file] }

    COLLECT_SIZES(ch_sizes)
    ch_versions = ch_versions.mix(COLLECT_SIZES.out.versions)
    ch_multiqc_files = ch_multiqc_files.mix(COLLECT_SIZES.out.multiqc_files)

    emit:
    h5ad          = ch_h5ad

    multiqc_files = ch_multiqc_files
    versions      = ch_versions                     // channel: [ versions.yml ]
}
