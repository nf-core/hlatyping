//
// Alignment with BWA-MEM2
//

include { BWAMEM2_MEM             } from '../../../modules/nf-core/bwamem2/mem/main'
include { BAM_SORT_STATS_SAMTOOLS } from '../../nf-core/bam_sort_stats_samtools/main'

workflow FASTQ_ALIGN_BWAMEM2 {
    take:
    ch_reads // channel (mandatory): [ val(meta), [ path(reads) ] ]
    ch_index // channel (mandatory): [ val(meta2), path(index) ]
    val_sort_bam // boolean (mandatory): true or false
    ch_fasta_fai // channel (optional) : [ val(meta3), path(fasta), path(fai) ]

    main:

    //
    // Map reads with BWA-MEM2
    //
    ch_fasta = ch_fasta_fai.map { meta, fasta, _fai -> [meta, fasta] }
    BWAMEM2_MEM(ch_reads, ch_index, ch_fasta, val_sort_bam)

    //
    // Sort, index BAM file and run samtools stats, flagstat and idxstats
    //

    BAM_SORT_STATS_SAMTOOLS(BWAMEM2_MEM.out.bam, ch_fasta_fai)

    emit:
    bam_orig = BWAMEM2_MEM.out.bam // channel: [ val(meta), path(bam) ]
    bam      = BAM_SORT_STATS_SAMTOOLS.out.bam // channel: [ val(meta), path(bam) ]
    index    = BAM_SORT_STATS_SAMTOOLS.out.index // channel: [ val(meta), path(index) ]
    stats    = BAM_SORT_STATS_SAMTOOLS.out.stats // channel: [ val(meta), path(stats) ]
    flagstat = BAM_SORT_STATS_SAMTOOLS.out.flagstat // channel: [ val(meta), path(flagstat) ]
    idxstats = BAM_SORT_STATS_SAMTOOLS.out.idxstats // channel: [ val(meta), path(idxstats) ]
}
