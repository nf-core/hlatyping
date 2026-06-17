//
// Build-if-null GRCh38 indices (faidx/bwa/STAR). bwa/STAR builds are gated on a non-empty
// per-aligner FASTA channel, present only when DNA/RNA FASTQ samples exist.
//
include { SAMTOOLS_FAIDX      } from '../../../modules/nf-core/samtools/faidx/main'
include { BWA_INDEX           } from '../../../modules/nf-core/bwa/index/main'
include { STAR_GENOMEGENERATE } from '../../../modules/nf-core/star/genomegenerate/main'

workflow PREPARE_GENOME {
    take:
    ch_fasta          // channel (value): [ val(meta), path(fasta) ]
    ch_fasta_for_bwa  // channel: [ val(meta), path(fasta) ]  — emits iff DNA FASTQ present (gate)
    ch_fasta_for_star // channel: [ val(meta), path(fasta) ]  — emits iff RNA FASTQ present (gate)
    ch_gtf            // channel (value): [ val(meta), path(gtf) ]  ([[:],[]] for genome-only)

    main:
    // bwa/star/faidx emit versions on the `versions` topic (collected globally) — no .versions output.
    def ch_fai = params.fasta_fai
        ? channel.value([[id: 'genome'], file(params.fasta_fai, checkIfExists: true)])
        : SAMTOOLS_FAIDX(ch_fasta.map { meta, fasta -> [meta, fasta, []] }, false).fai

    def ch_fasta_fai = ch_fasta
        .combine(ch_fai)
        .map { fmeta, fasta, _faimeta, fai -> [fmeta, fasta, fai] }

    def ch_bwa = params.bwa
        ? channel.value([[id: 'bwa'], file(params.bwa, checkIfExists: true)])
        : BWA_INDEX(ch_fasta_for_bwa).index

    def ch_star = params.star_index
        ? channel.value([[id: 'star'], file(params.star_index, checkIfExists: true)])
        : STAR_GENOMEGENERATE(ch_fasta_for_star, ch_gtf).index

    emit:
    // .first() -> value channel so the single built index broadcasts to every sample (else only sample 1 aligns).
    fasta_fai = ch_fasta_fai.first()
    bwa       = ch_bwa.first()
    star      = ch_star.first()
}
