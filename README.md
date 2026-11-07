# CAPCert reproduction package (original training)

Source, verification harnesses, experiment runners and result-generation tools
for *CAPCert: Obfuscation-Invariant, End-to-End Certified Robustness for
Graph-Based Malware Detection via Canonical Content-Addressed Partitioning*.

**Start here:** `notebooks/CAPCert_Reproduction.ipynb` runs the whole pipeline
in Colab and writes logs, checkpoints and tables you can download. Locally,
`make demo` does the same thing.

---

## Original datasets

The CAPCert pipeline is evaluated on three real malware corpora plus a PDB
ground-truth corpus for the recovery study. Download links and handling
notes:

| Corpus | Role in the paper | Link |
|---|---|---|
| **DikeDataset** | benign + malicious PE samples with per-file family labels | [github.com/iosifache/DikeDataset](https://github.com/iosifache/DikeDataset) · [HF mirror](https://huggingface.co/datasets/cycloevan/DikeDataset/blob/main/README.md) |
| **Dataset-K** | PE / Windows API graph corpus from MalGraph (ref [7]) | MalGraph paper — [nesa.zju.edu.cn](https://nesa.zju.edu.cn/download/lx_pdf_malgraph.pdf); related — [Mal2GCN](https://arxiv.org/pdf/2108.12473), [MalSensor](https://wu-yueming.github.io/Files/TOSEM2024_MalSensor.pdf) |
| **BIG-2015** | Microsoft Malware Classification Challenge (family labels) | [kaggle.com/competitions/malware-classification](https://www.kaggle.com/competitions/malware-classification) · paper [arxiv.org/abs/1802.10135](https://arxiv.org/pdf/1802.10135) |
| **PDB ground truth** | block/edge labels for the recovery study (Table XXI) | build with [Ghidra 11.3](https://github.com/NationalSecurityAgency/ghidra/releases) over open-source MSVC builds |

Baseline comparisons use these additional public corpora:

| Corpus | Link |
|---|---|
| EMBER 2018 | [paper](https://arxiv.org/pdf/1804.04637) · [code](https://github.com/elastic/ember) · [Elastic release](https://www.elastic.co/blog/introducing-ember-open-source-classifier-and-dataset) |
| EMBER 2024 | [paper](https://arxiv.org/abs/2506.05074) |

Every output file carries a provenance stamp (`measured` for the real
corpora, `original` for the corpus shipped with this repo, `reference` for
values transcribed from the manuscript). `docs/ORIGINAL_DATASETS.md` has
more context; `docs/REAL_DATA.md` has the manifest schema and the
`--manifest` wiring.

---

## Quick start

```bash
pip install -r requirements.txt       # or: conda env create -f environment.yml
make verify                           # TV1-TV5 + the L0 negative control, ~3 min
make demo                             # the whole thing, ~10-20 min
```

Docker:

```bash
docker build -t capcert-artifact .
docker run --rm -v "$PWD/results:/artifact/results" capcert-artifact make demo
```

Only `numpy`, `scipy`, `PyYAML` and `z3-solver` are needed for the verification
suite and the certificate. `torch` is used for training; without it the
pipeline falls back to a numpy backend and everything still runs.

---

## What is here

```
capcert/              the implementation
  ir.py               P-code-like IR, fixed-width bit-vector semantics
  image.py            byte container + the dependency-recording accessor
  lfr.py              Stage 1: Local Function Recovery, and the independent
                      dependency closure the L0 audit compares against
  rewrite.py          R1-R6, the termination measure mu, critical-pair sites
  canonical.py        Stage 2: kappa, the canonical digest, C(x), d(x,x')
  partition.py        Stage 3: keyed k-overlap partitioning
  model.py            Stage 4: base classifier + certified-margin MIL (eq. 30)
  vote.py             Stage 5: asymmetric threshold vote, rho_hat (eq. 25)
  edits.py            the nine Corollary 1 edit families and their bounds
  stats.py            Clopper-Pearson, bootstrap, McNemar, Wilcoxon, Holm
  datasets.py         manifest schema/loader + the original training corpus
  pipeline.py         corpus -> canonical -> features -> verdict
  provenance.py       run stamps, JSONL logs, manifests

verification/         TV1-TV5 and the negative control
experiments/          EV1-EV9 and the packed-subset run
reporting/            manuscript_values.yaml, make_tables.py,
                      verify_against_manuscript.py
baselines/            REGISTRY.yaml: all fourteen, with pins and commitments
rust/lfr/             the L0 accessor contract in Rust, with its own tests
data/                 manifest schema and split documentation
docs/                 REAL_DATA.md, RESTRICTED.md
results/              everything a run writes: logs/, checkpoints/, tables/
```

---

## The verification suite

These check the *implementation* against the proven results. Passing does not
establish a guarantee — the proofs do that. A failure reveals a defect.

| check | what it does | expected |
|---|---|---|
| **TV1** | records mu before and after every rewrite step over the corpus | 0 steps that fail to decrease mu |
| **TV2** | generates critical pairs and decides joinability by normalising both sides | all joinable |
| **TV3** | discharges the folding, identity and flag obligations with Z3 at 8/16/32/64 bits | all valid |
| **TV4** | L0 audit, L0 differential, Corollary 1 bounds, Theorem 2 cap, Theorem 4 conformance | 0 violations |
| **TV5** | runs the Theorem 5 construction and compares cost with 1/q_k; occupancy against eq. (32) | measurement only |
| **L0 inject** | reinstates the jump-table off-by-one of Section VII-J | **must fail**, or the audit is vacuous |

The negative controls matter as much as the positive results:

```bash
python verification/l0_fault_injection.py          # injected phase MUST report violations
python verification/tv1_termination.py --emulate-name-order   # MUST fail
```

If a negative control passes, the check above it is proving nothing — and the
suite says so rather than reporting a clean sheet.

### Three defects this audit found while the artifact was being written

Recorded because they are the argument for having the audit at all:

1. **R4 propagated a folded constant across a redefinition.** Caught as an
   edit in `T_inv` with a non-zero footprint. Fixed by requiring the output to
   be a single-definition unique.
2. **Inlined callees kept unprefixed branch targets**, so R1 silently stopped
   merging inside them. Caught the same way.
3. **The L0 audit was nearly vacuous.** Comparing only *declared* reads cannot
   see a read that was never declared — which is exactly the jump-table defect.
   Fixed by instrumenting below the recording logic (`Accessor.undeclared()`),
   in both the Python and the Rust accessor.

---

## Reproducing a table

```bash
make demo                                  # produces the logs
python reporting/make_tables.py            # Tables XV, XVII, XX, XXII-XXV, XXVII, XXX
python reporting/verify_against_manuscript.py
```

Tables are built from `results/logs/**/*.manifest.json` and from nothing else,
so any cell can be traced back to the run that produced it. The verifier prints
one of five verdicts per claim: `REPRODUCED`, `DIVERGENT`, `UNCOVERED`,
`STRUCTURAL` (computed from the original training corpus) or `N/A` (the
manuscript has no value).

---

## Restricted component

The adaptive attack generator of Section VIII-E is **not in this repository**
and will not be. `docs/RESTRICTED.md` states what it is, why it is withheld,
what is here instead, and — the part that matters for reproduction — that no
certified result depends on it. The white-box attacks in
`experiments/ev4_attacks.py` operate on the canonical representation, need the
hash keys, and cannot be pointed at a PE file to produce a working evasive
sample.

---

## Licence and citation

Code: MIT (see `LICENSE`). `data/manifests/` documents the manifest schema
and how to assemble the splits from the datasets linked above.

Fill in `CITATION.cff` with the archived DOI and release tag before release.
