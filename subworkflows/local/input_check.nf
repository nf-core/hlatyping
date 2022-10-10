//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_fastq_channel(LinkedHashMap row) {
    // create meta map
    def meta = [:]
    meta.id         = row.sample
    meta.single_end = row.single_end.toBoolean()
    meta.data_type = "fastq"
    if (row.seq_type == "dna" || row.seq_type == "rna") {
            meta.seq_type   = row.seq_type
    }
    else {
        exit 1, "ERROR: Please check input samplesheet -> Invalid sequencing type specified!\n${row.seq_type}"
    }

    // add path(s) of the fastq file(s) to the meta map
    def bam_provided = ("bam" in row) & (row["bam"] != "")
    def fastq_provided = row["fastq_1"] != ""
    def fastq_meta = []

    if (bam_provided & fastq_provided) {
        exit 1, "ERROR: Please check input samplesheet -> Please provide fastq OR bam input per samplesheet row!\n${row}"
    }

    if(fastq_provided) {
        if (!file(row.fastq_1).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> Read 1 FastQ file does not exist!\n${row.fastq_1}"
        }
        if (meta.single_end) {
            fastq_meta = [ meta, [ file(row.fastq_1) ] ]
        } else {
            if (!file(row.fastq_2).exists()) {
                exit 1, "ERROR: Please check input samplesheet -> Read 2 FastQ file does not exist!\n${row.fastq_2}"
            }
            fastq_meta = [ meta, [ file(row.fastq_1), file(row.fastq_2) ] ]
        }
    }

    if (bam_provided) {
        if (!file(row.bam).exists()) {
            exit 1, "ERROR: Please check input samplesheet -> BAM file does not exist!\n${row.bam}"
        }
        else {
            meta.data_type = "bam"
            fastq_meta = [ meta, [ file(row.bam) ] ]
        }
    }
    return fastq_meta
}
