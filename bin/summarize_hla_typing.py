#!/usr/bin/env python
from __future__ import annotations

import argparse
import csv
import sys
from pathlib import Path

import mhcgnomes

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


def extract_optitype(path: str) -> list[str]:
    """Read allele tokens from an OptiType result TSV.

    Args:
        path: Path to the OptiType ``*.tsv`` output.

    Returns:
        The six A/B/C alleles of the first (optimal) solution row.
    """
    with open(path, newline="") as fh:
        rows = list(csv.reader(fh, delimiter="\t"))
    if len(rows) < 2:
        return []
    header = rows[0]
    cols = [i for i, h in enumerate(header) if h in {"A1", "A2", "B1", "B2", "C1", "C2"}]
    data = rows[1]
    return [data[i] for i in cols if i < len(data) and data[i].strip()]


def extract_hlahd(path: str) -> list[str]:
    """Read allele tokens from an HLA-HD ``*_final.result.txt``.

    Args:
        path: Path to the result file with per-locus ``LOCUS<TAB>a1<TAB>a2`` rows.

    Returns:
        Every allele token across all locus rows.
    """
    tokens = []
    for line in Path(path).read_text().splitlines():
        fields = line.rstrip("\n").split("\t")
        if len(fields) < 2:
            continue
        tokens.extend(tok.strip() for tok in fields[1:])
    return tokens


def extract_hlala(path: str) -> list[str]:
    """Read allele tokens from an HLA*LA ``R1_bestguess_G.txt``.

    Args:
        path: Path to the HLA*LA best-guess TSV.

    Returns:
        The first call of each row's ``Allele`` field, which may list
        ``;``-separated alternatives.
    """
    tokens = []
    with open(path, newline="") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        for row in reader:
            allele = (row.get("Allele") or "").strip()
            if allele:
                tokens.append(allele.split(";")[0])
    return tokens


def extract_spechla(path: str) -> list[str]:
    """Read allele tokens from a SpecHLA ``hla.result.txt``.

    Args:
        path: Path to the result file: an optional leading ``#`` comment line, a
            header row, then one wide data row whose first column is the sample.

    Returns:
        Every allele token from the data row.
    """
    lines = [ln for ln in Path(path).read_text().splitlines() if ln.strip() and not ln.startswith("#")]
    if len(lines) < 2:
        return []
    data = lines[1].split("\t")
    return [tok.strip() for tok in data[1:]]


def extract_immunotype(path: str) -> list[str]:
    """Read allele tokens from an immunotype ``*_typing.tsv``.

    Args:
        path: Path to the result file with a ``sample<TAB>typing`` header and a
            ``;``-joined allele list in the ``typing`` column.

    Returns:
        The alleles from the ``typing`` column.
    """
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


def normalize(token: str) -> tuple[str, str, str, str] | None:
    """Normalize one raw allele token with mhcgnomes.

    Args:
        token: Raw allele string from a tool's output.

    Returns:
        ``(gene, hla_class, full, two_field)``, or ``None`` if the token is a
        placeholder, not a parseable allele, or a non-reportable locus.
    """
    tok = token.strip()
    if tok.lower() in PLACEHOLDERS:
        return None
    parsed = mhcgnomes.parse(tok, raise_on_error=False)
    if not isinstance(parsed, mhcgnomes.Allele):
        sys.stderr.write(f"WARNING: could not parse allele '{token}'\n")
        return None
    hla_class = GENE_CLASS.get(parsed.gene.name)
    if hla_class is None:
        sys.stderr.write(f"WARNING: skipping non-reportable locus '{parsed.gene.name}' ('{token}')\n")
        return None
    return parsed.gene.name, hla_class, parsed.to_string(), parsed.restrict_allele_fields(2).to_string()


def summarize_one(tokens: list[str]) -> dict[str, str]:
    """Build the four allele columns for one sample/tool from raw tokens.

    Args:
        tokens: Raw allele tokens extracted from one tool's output.

    Returns:
        Mapping of ``class_I``, ``class_I_2field``, ``class_II`` and
        ``class_II_2field`` to ``;``-joined alleles (``NA`` when a class is empty).
    """
    buckets: dict[str, list[tuple[str, str, str]]] = {"I": [], "II": []}
    for tok in tokens:
        res = normalize(tok)
        if res is None:
            continue
        gene, hla_class, full, two_field = res
        buckets[hla_class].append((gene, full, two_field))

    out = {}
    for hla_class, label in (("I", "class_I"), ("II", "class_II")):
        # One sort keeps the full and 2-field columns row-aligned.
        items = sorted(buckets[hla_class], key=lambda x: (GENE_ORDER.get(x[0], 99), x[1]))
        out[label] = ";".join(it[1] for it in items) if items else "NA"
        out[f"{label}_2field"] = ";".join(it[2] for it in items) if items else "NA"
    return out


def parse_filename(path: str) -> tuple[str, str]:
    """Recover the sample and tool from a ``<sample>__<tool>.txt`` filename.

    Args:
        path: Path whose basename encodes the sample id and tool name.

    Returns:
        ``(sample, tool)``.
    """
    stem = Path(path).name
    if stem.endswith(".txt"):
        stem = stem[:-4]
    sample, _, tool = stem.rpartition("__")
    return sample, tool


def main() -> None:
    """Parse CLI arguments and write the harmonized typing TSV."""
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
