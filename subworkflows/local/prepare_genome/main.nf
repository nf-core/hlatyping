//
// Build-if-null genome indices: faidx always, bwa/STAR only when their gate FASTA channel emits
// (i.e. DNA/RNA FASTQ samples are present), so a DNA-only run never builds a STAR index.
//
include { SAMTOOLS_FAIDX      } from '../../../modules/nf-core/samtools/faidx/main'
include { BWA_INDEX           } from '../../../modules/nf-core/bwa/index/main'
include { STAR_GENOMEGENERATE } from '../../../modules/nf-core/star/genomegenerate/main'

workflow PREPARE_GENOME {
    take:
    ch_fasta_for_bwa  // channel: [ val(meta), path(fasta) ]  — emits iff DNA FASTQ present (gate)
    ch_fasta_for_star // channel: [ val(meta), path(fasta) ]  — emits iff RNA FASTQ present (gate)
    ch_gtf            // channel (value): [ val(meta), path(gtf) ]  ([[:],[]] for genome-only)

    main:
    // faidx needs the genome FASTA if either aligner does; .first() => a single faidx task.
    def ch_fasta = ch_fasta_for_bwa.mix(ch_fasta_for_star).first()

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
    // .first() => value channel, so the single built index broadcasts to every sample
    fasta_fai = ch_fasta_fai.first()
    bwa       = ch_bwa.first()
    star      = ch_star.first()
}
