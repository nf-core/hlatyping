//
// Align FASTQ to the genome: DNA via bwa-mem, RNA via STAR (genome-only); both sort + index downstream.
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
    FASTQ_ALIGN_BWA(ch_dna_reads, ch_bwa, true, ch_fasta_fai)

    // empty transcripts fai => STAR's transcriptome/quant branch no-ops (genome-only)
    FASTQ_ALIGN_STAR(ch_rna_reads, ch_star, ch_gtf, true, ch_fasta_fai, channel.value([[id: 'no_transcripts'], [], []]))

    emit:
    bam      = FASTQ_ALIGN_BWA.out.bam.mix(FASTQ_ALIGN_STAR.out.bam)
    bai      = FASTQ_ALIGN_BWA.out.index.mix(FASTQ_ALIGN_STAR.out.index)
    stats    = FASTQ_ALIGN_BWA.out.stats.mix(FASTQ_ALIGN_STAR.out.stats)
    flagstat = FASTQ_ALIGN_BWA.out.flagstat.mix(FASTQ_ALIGN_STAR.out.flagstat)
    idxstats = FASTQ_ALIGN_BWA.out.idxstats.mix(FASTQ_ALIGN_STAR.out.idxstats)
}
