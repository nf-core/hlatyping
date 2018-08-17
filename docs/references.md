# HLA references

The **nf-core/hlatyping** pipeline uses a default HLA reference which is located in the pipelines root directory in `./data/references` and the corresponding mapper indices in `./data/indices/yara`. The references are based on the IMGT/HLA Release 3.14.0, July 2013, and have been processed as described in the [publication](https://doi.org/10.1093/bioinformatics/btu548) of OptiType. 

You can always download new versions from the [HLA database](https://www.ebi.ac.uk/ipd/imgt/hla/docs/release.html), but 
be aware that these allele sets are missing intron sequence information, which will have a negative influence in the HLA typing outcome in case of DNAseq. 
 
 We are currently looking into a dynamic solution, in order to build pre-processed input HLA references from current HLA allele information from the IPD-IMGT/HLA database.
