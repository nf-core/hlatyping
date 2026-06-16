//
// Build or resolve GRCh38 reference indices for the alignment step.
// Indices are built only when not provided by the user (build-if-null); the bwa/STAR
// builds are gated on the caller passing a non-empty per-aligner FASTA channel (present
// only when DNA/RNA FASTQ samples exist).
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
    // NOTE: bwa/index, star/genomegenerate and samtools/faidx emit tool versions on the
    // `versions` TOPIC channel (not a classic `.versions` output). The main workflow
    // collects them globally via channel.topic("versions") — do NOT mix .versions here.

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
    fasta_fai = ch_fasta_fai // channel: [ val(meta), path(fasta), path(fai) ]
    bwa       = ch_bwa       // channel: [ val(meta), path(index) ]
    star      = ch_star      // channel: [ val(meta), path(index) ]
}
