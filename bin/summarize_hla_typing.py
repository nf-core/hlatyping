#!/usr/bin/env python
"""Harmonize HLA typing outputs from multiple tools into one tidy TSV.

Input files are named ``<sample>__<tool>.txt`` (the workflow renames each tool's
output via collectFile so the filename carries the sample id and tool name).
Each tool's native format is parsed into raw allele tokens, every token is
normalized with mhcgnomes, alleles are split into class I / II by gene, and one
row per (sample, tool) is written:

    sample  predictor  class_i_original  class_ii_original  class_i_2field  class_ii_2field
"""

import argparse
import csv
import re
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
GENE_RE = re.compile(r"^(?:HLA-)?([A-Z0-9]+)\*([0-9A-Z:]+)")


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


# --- normalization ------------------------------------------------------------
def _gene_name(parsed):
    """Best-effort gene symbol from a mhcgnomes result (defensive across versions)."""
    name = getattr(parsed, "gene_name", None)
    if name:
        return name
    gene = getattr(parsed, "gene", None)
    if gene is not None:
        return getattr(gene, "name", None)
    return None


def two_field(canonical):
    """Truncate a canonical allele string to two fields, dropping any trailing
    group/expression suffix letters (G, P, N, ...)."""
    if "*" not in canonical:
        return canonical
    prefix, fields = canonical.split("*", 1)
    parts = fields.split(":")
    trunc = ":".join(parts[:2])
    trunc = re.sub(r"[A-Za-z]+$", "", trunc)
    return f"{prefix}*{trunc}"


def normalize(token):
    """Return (gene, cls, original, two_field_str) or None if it can't be classified."""
    tok = token.strip()
    if tok.lower() in PLACEHOLDERS:
        return None
    try:
        parsed = mhcgnomes.parse(tok)
    except Exception:
        parsed = None
    gene = _gene_name(parsed) if parsed is not None else None
    original = parsed.to_string() if parsed is not None else None
    if gene is None or original is None:
        # mhcgnomes could not parse it cleanly: fall back to a regex render so
        # G-groups / odd tokens still appear instead of silently vanishing.
        m = GENE_RE.match(tok)
        if not m:
            sys.stderr.write(f"WARNING: could not parse allele '{token}'\n")
            return None
        gene = m.group(1)
        original = tok if tok.upper().startswith("HLA-") else f"HLA-{tok}"
    cls = GENE_CLASS.get(gene)
    if cls is None:
        sys.stderr.write(f"WARNING: skipping non-reportable locus '{gene}' ('{token}')\n")
        return None
    return gene, cls, original, two_field(original)


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
    for cls, prefix in (("I", "class_i"), ("II", "class_ii")):
        # one sort drives both columns so original/2field stay row-aligned
        items = sorted(buckets[cls], key=lambda x: (GENE_ORDER.get(x[0], 99), x[1]))
        out[f"{prefix}_original"] = ";".join(it[1] for it in items) if items else "NA"
        out[f"{prefix}_2field"] = ";".join(it[2] for it in items) if items else "NA"
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
    ap.add_argument("-o", "--output", default="hla_summary.tsv")
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

    fieldnames = ["sample", "predictor", "class_i_original", "class_ii_original", "class_i_2field", "class_ii_2field"]
    with open(args.output, "w", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    main()
