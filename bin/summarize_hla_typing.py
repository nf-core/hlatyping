#!/usr/bin/env python
"""Harmonize HLA typing outputs from multiple tools into one tidy TSV.

Input files are named ``<sample>__<tool>.txt`` (the workflow renames each tool's
output via collectFile so the filename carries the sample id and tool name).
Each tool's native format is parsed into raw allele tokens, every token is
normalized with mhcgnomes, alleles are split into class I / II by gene, and one
row per (sample, tool) is written:

    sample  predictor  class_I  class_I_2field  class_II  class_II_2field
"""

import argparse
import csv
import sys
from pathlib import Path

import mhcgnomes

# --- canonical reportable loci -> class ---------------------------------------
CLASS_I_ORDER = ["A", "B", "C", "E", "F", "G"]
CLASS_II_ORDER = [
    "DRA", "DRB1", "DRB3", "DRB4", "DRB5",
    "DQA1", "DQB1", "DPA1", "DPB1",
    "DMA", "DMB", "DOA", "DOB",
]
GENE_CLASS = {g: "I" for g in CLASS_I_ORDER}
GENE_CLASS.update({g: "II" for g in CLASS_II_ORDER})
GENE_ORDER = {g: i for i, g in enumerate(CLASS_I_ORDER + CLASS_II_ORDER)}

TOOLS = ["optitype", "hlahd", "hlala", "spechla", "immunotype"]
PLACEHOLDERS = {"-", "", "not typed", "couldn't read result.", "na"}


# --- per-tool raw token extractors --------------------------------------------
def extract_optitype(path):
    """OptiType TSV: header has A1 A2 B1 B2 C1 C2 ...; take the first solution row."""
    with open(path, newline="") as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    if len(rows) < 2:
        return []
    header = rows[0]
    cols = [i for i, h in enumerate(header) if h in {"A1", "A2", "B1", "B2", "C1", "C2"}]
    data = rows[1]
    return [data[i] for i in cols if i < len(data) and data[i].strip()]


def extract_hlahd(path):
    """HLA-HD *_final.result.txt: per-locus rows LOCUS<TAB>allele1<TAB>allele2."""
    tokens = []
    for line in Path(path).read_text().splitlines():
        fields = line.rstrip("\n").split("\t")
        if len(fields) < 2:
            continue
        tokens.extend(tok.strip() for tok in fields[1:])
    return tokens


def extract_hlala(path):
    """HLA*LA R1_bestguess_G.txt: TSV with Locus, Chromosome, Allele, ...;
    the Allele field may hold ';'-separated alternatives (take the first)."""
    tokens = []
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            allele = (row.get("Allele") or "").strip()
            if allele:
                tokens.append(allele.split(";")[0])
    return tokens


def extract_spechla(path):
    """SpecHLA hla.result.txt: an optional leading '# ...' comment line, then a
    header row and a single data row (wide TSV); data row col0 is Sample, the
    rest are alleles."""
    lines = [ln for ln in Path(path).read_text().splitlines() if ln.strip() and not ln.startswith("#")]
    if len(lines) < 2:
        return []
    data = lines[1].split("\t")
    return [tok.strip() for tok in data[1:]]


def extract_immunotype(path):
    """immunotype *_typing.tsv: header 'sample<TAB>typing'; typing is ';'-joined."""
    lines = Path(path).read_text().splitlines()
    if len(lines) < 2:
        return []
    data = lines[1].split("\t")
    if len(data) < 2:
        return []
    return [tok.strip() for tok in data[1].split(";")]


EXTRACTORS = {
    "optitype": extract_optitype,
    "hlahd": extract_hlahd,
    "hlala": extract_hlala,
    "spechla": extract_spechla,
    "immunotype": extract_immunotype,
}


# --- normalization (delegated to mhcgnomes) -----------------------------------
def normalize(token):
    """Parse a raw allele token with mhcgnomes and return
    (gene, cls, full_string, two_field_string), or None if the token is a
    placeholder, unparseable, or a non-reportable locus.

    mhcgnomes does all the normalization: canonical naming with the ``HLA-``
    prefix (``to_string``) and the 2-field form (``restrict_allele_fields``)."""
    tok = token.strip()
    if tok.lower() in PLACEHOLDERS:
        return None
    try:
        parsed = mhcgnomes.parse(tok)
    except Exception:
        parsed = None
    if not isinstance(parsed, mhcgnomes.Allele):
        sys.stderr.write(f"WARNING: could not parse allele '{token}'\n")
        return None
    cls = GENE_CLASS.get(parsed.gene.name)
    if cls is None:
        sys.stderr.write(f"WARNING: skipping non-reportable locus '{parsed.gene.name}' ('{token}')\n")
        return None
    return parsed.gene.name, cls, parsed.to_string(), parsed.restrict_allele_fields(2).to_string()


def summarize_one(tokens):
    """tokens -> dict of the four allele columns for one (sample, tool)."""
    buckets = {"I": [], "II": []}  # each entry: (gene, original, two_field)
    for tok in tokens:
        res = normalize(tok)
        if res is None:
            continue
        gene, cls, original, tf = res
        buckets[cls].append((gene, original, tf))

    out = {}
    for cls, label in (("I", "class_I"), ("II", "class_II")):
        # one sort drives both columns so the full and 2-field stay row-aligned
        items = sorted(buckets[cls], key=lambda x: (GENE_ORDER.get(x[0], 99), x[1]))
        out[label] = ";".join(it[1] for it in items) if items else "NA"
        out[f"{label}_2field"] = ";".join(it[2] for it in items) if items else "NA"
    return out


def parse_filename(path):
    """'<sample>__<tool>.txt' -> (sample, tool)."""
    stem = Path(path).name
    if stem.endswith(".txt"):
        stem = stem[:-4]
    sample, _, tool = stem.rpartition("__")
    return sample, tool


def main():
    ap = argparse.ArgumentParser(description="Harmonize HLA typing outputs into one TSV")
    ap.add_argument("inputs", nargs="+", help="<sample>__<tool>.txt result files")
    ap.add_argument("-o", "--output", default="hlatyping_results.tsv")
    args = ap.parse_args()

    rows = []
    for path in args.inputs:
        sample, tool = parse_filename(path)
        if tool not in EXTRACTORS:
            sys.stderr.write(f"WARNING: unknown tool '{tool}' for {path}; skipping\n")
            continue
        cols = summarize_one(EXTRACTORS[tool](path))
        rows.append({"sample": sample, "predictor": tool, **cols})

    rows.sort(key=lambda r: (r["sample"], TOOLS.index(r["predictor"]) if r["predictor"] in TOOLS else 99))

    fieldnames = ["sample", "predictor", "class_I", "class_I_2field", "class_II", "class_II_2field"]
    with open(args.output, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
