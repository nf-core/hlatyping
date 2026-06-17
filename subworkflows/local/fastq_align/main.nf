//
// Align genuine FASTQ to GRCh38: DNA -> FASTQ_ALIGN_BWA, RNA -> FASTQ_ALIGN_STAR (genome-only).
// Both end in BAM_SORT_STATS_SAMTOOLS, so the genome emits share one shape.
//
include { FASTQ_ALIGN_BWA  } from '../../nf-core/fastq_align_bwa/main'
include { FASTQ_ALIGN_STAR } from '../../nf-core/fastq_align_star/main'

workflow FASTQ_ALIGN {
    take:
    ch_dna_reads // channel: [ val(meta), [ path(reads) ] ]  (seq_type == dna)
    ch_rna_reads // channel: [ val(meta), [ path(reads) ] ]  (seq_type == rna)
    ch_bwa       // channel: [ val(meta), path(index) ]
    ch_star      // channel: [ val(meta), path(index) ]
    ch_fasta_fai // channel: [ val(meta), path(fasta), path(fai) ]
    ch_gtf       // channel: [ val(meta), path(gtf) ]

    main:
    // DNA: bwa-mem, coordinate-sorted (3rd arg = val_sort_bam).
    FASTQ_ALIGN_BWA(ch_dna_reads, ch_bwa, true, ch_fasta_fai)

    // STAR genome-only. Dummy transcripts fai: no --quantMode, so the transcriptome branch no-ops.
    FASTQ_ALIGN_STAR(ch_rna_reads, ch_star, ch_gtf, true, ch_fasta_fai, channel.value([[id: 'no_transcripts'], [], []]))

    emit:
    bam      = FASTQ_ALIGN_BWA.out.bam.mix(FASTQ_ALIGN_STAR.out.bam)
    bai      = FASTQ_ALIGN_BWA.out.index.mix(FASTQ_ALIGN_STAR.out.index)
    stats    = FASTQ_ALIGN_BWA.out.stats.mix(FASTQ_ALIGN_STAR.out.stats)
    flagstat = FASTQ_ALIGN_BWA.out.flagstat.mix(FASTQ_ALIGN_STAR.out.flagstat)
    idxstats = FASTQ_ALIGN_BWA.out.idxstats.mix(FASTQ_ALIGN_STAR.out.idxstats)
}
