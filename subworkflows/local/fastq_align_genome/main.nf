include { SAMTOOLS_FAIDX          } from '../../../modules/nf-core/samtools/faidx/main'
include { BWAMEM2_INDEX           } from '../../../modules/nf-core/bwamem2/index/main'
include { STAR_GENOMEGENERATE     } from '../../../modules/nf-core/star/genomegenerate/main'
include { FASTQ_ALIGN_DNA         } from '../../nf-core/fastq_align_dna/main'
include { FASTQ_ALIGN_STAR        } from '../../nf-core/fastq_align_star/main'
include { BAM_SORT_STATS_SAMTOOLS } from '../../nf-core/bam_sort_stats_samtools/main'
include { validateHlalaReference  } from '../utils_nfcore_hlatyping_pipeline'

workflow FASTQ_ALIGN_GENOME {
    take:
    ch_reads        // channel: [ val(meta), [ reads ] ]
    genome_fasta    // string: path to genome FASTA
    fasta_fai       // string: path to FASTA index
    bwamem2_index   // string: path to bwa-mem2 index
    star_index      // string: path to STAR index
    gtf             // string: path to GTF
    check_hlala_ref // boolean: fail on contig names HLA*LA cannot match

    main:
    ch_reads
        .branch { meta, _reads ->
            rna: meta.seq_type == 'rna'
            dna: true
        }
        .set { ch_reads_by_type }

    def ch_fasta_dna = ch_reads_by_type.dna.map { _meta, _reads -> [[id: 'genome'], file(genome_fasta, checkIfExists: true)] }.first()
    def ch_fasta_rna = ch_reads_by_type.rna.map { _meta, _reads -> [[id: 'genome'], file(genome_fasta, checkIfExists: true)] }.first()
    def ch_fasta = ch_fasta_dna.mix(ch_fasta_rna).first()
    def ch_gtf = gtf
        ? channel.value([[id: 'genome'], file(gtf, checkIfExists: true)])
        : channel.value([[:], []])

    def ch_fai = fasta_fai
        ? channel.value([[id: 'genome'], file(fasta_fai, checkIfExists: true)])
        : SAMTOOLS_FAIDX(ch_fasta.map { meta, fasta -> [meta, fasta, []] }, false).fai
    def ch_fasta_fai = ch_fasta.combine(ch_fai).map { meta, fasta, _meta, fai -> [meta, fasta, fai] }.first()

    if (check_hlala_ref) {
        ch_fasta_dna.combine(ch_fai).map { _meta, _fasta, _meta2, fai -> validateHlalaReference(fai) }
    }

    def ch_bwamem2 = bwamem2_index
        ? channel.value([[id: 'bwamem2'], file(bwamem2_index, checkIfExists: true)])
        : BWAMEM2_INDEX(ch_fasta_dna).index
    def ch_star = star_index
        ? channel.value([[id: 'star'], file(star_index, checkIfExists: true)])
        : STAR_GENOMEGENERATE(ch_fasta_rna, ch_gtf).index

    FASTQ_ALIGN_DNA(ch_reads_by_type.dna, ch_bwamem2, ch_fasta_dna, 'bwamem2', false)
    BAM_SORT_STATS_SAMTOOLS(FASTQ_ALIGN_DNA.out.bam, ch_fasta_fai)
    FASTQ_ALIGN_STAR(ch_reads_by_type.rna, ch_star, ch_gtf, true, ch_fasta_fai, channel.value([[id: 'no_transcripts'], [], []]))

    emit:
    bam_bai = BAM_SORT_STATS_SAMTOOLS.out.bam.join(BAM_SORT_STATS_SAMTOOLS.out.index)
        .mix(FASTQ_ALIGN_STAR.out.bam.join(FASTQ_ALIGN_STAR.out.index)) // channel: [ val(meta), path(bam), path(bai) ]
    mqc     = BAM_SORT_STATS_SAMTOOLS.out.stats
        .mix(
            BAM_SORT_STATS_SAMTOOLS.out.flagstat,
            BAM_SORT_STATS_SAMTOOLS.out.idxstats,
            FASTQ_ALIGN_STAR.out.stats,
            FASTQ_ALIGN_STAR.out.flagstat,
            FASTQ_ALIGN_STAR.out.idxstats,
            FASTQ_ALIGN_STAR.out.log_final,
        )
        .map { _meta, f -> f } // channel: path(mqc)
}
