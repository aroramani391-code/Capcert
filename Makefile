# CAPCert artifact.
#
#   make demo      run the whole pipeline on the synthetic corpus (~10 min)
#   make verify    the verification suite only, TV1-TV5 + the negative control
#   make tables    regenerate the manuscript tables from whatever logs exist
#   make check     verify + diff against the manuscript's claims
#   make clean     remove results/
#
# Everything writes into results/ and every file it writes carries a
# provenance stamp.  A run on the synthetic corpus is stamped "synthetic" and
# its tables are watermarked; see README.md.

PY      ?= python3
RESULTS ?= results
N       ?= 300
EPOCHS  ?= 40
T       ?= 5
SEEDS   ?= 0 1 2

.PHONY: all demo verify experiments tables check clean rust test help

all: demo

help:
	@grep -E '^#( |$$)' Makefile | sed 's/^# \{0,1\}//'

verify:
	$(PY) verification/tv1_termination.py --n 60  --results $(RESULTS)
	$(PY) verification/tv2_critical_pairs.py --n 40 --results $(RESULTS)
	$(PY) verification/tv3_smt.py                 --results $(RESULTS)
	$(PY) verification/tv4_conformance.py --n 30 --sequences 3 --results $(RESULTS)
	$(PY) verification/tv5_tightness.py --n 20    --results $(RESULTS)
	$(PY) verification/l0_fault_injection.py --n 20 --results $(RESULTS)

experiments:
	$(PY) experiments/ev1_invariance.py  --n 60  --repeats 2 --results $(RESULTS)
	$(PY) experiments/ev2_recovery.py    --n 40  --trials 2  --results $(RESULTS)
	$(PY) experiments/ev5_clean.py       --n $(N) --epochs $(EPOCHS) --t $(T) --seeds $(SEEDS) --results $(RESULTS)
	$(PY) experiments/ev3_certified.py   --n $(N) --epochs $(EPOCHS) --t $(T) --seeds $(SEEDS) --results $(RESULTS)
	$(PY) experiments/ev4_attacks.py     --n 200 --epochs 30 --t $(T) --budget-max 8 --results $(RESULTS)
	$(PY) experiments/ev6_generalization.py --n 200 --epochs 25 --t $(T) --results $(RESULTS)
	$(PY) experiments/ev7_efficiency.py  --n 120 --epochs 20 --t $(T) --results $(RESULTS)
	$(PY) experiments/ev8_partition.py   --n 80              --results $(RESULTS)
	$(PY) experiments/ev9_training.py    --n 150 --epochs 20 --t $(T) --results $(RESULTS)
	$(PY) experiments/ev_packed.py       --n $(N) --epochs 25 --t $(T) --seeds $(SEEDS) --results $(RESULTS)

tables:
	$(PY) reporting/make_tables.py --results $(RESULTS)

figures:
	$(PY) reporting/make_figures.py --results $(RESULTS)

check: tables figures
	$(PY) reporting/verify_against_manuscript.py --results $(RESULTS)

demo: verify experiments check

rust:
	cd rust/lfr && cargo test --quiet && cargo build --release --quiet

test: rust
	$(PY) verification/tv3_smt.py --quick --results $(RESULTS)
	$(PY) verification/l0_fault_injection.py --n 8 --results $(RESULTS)

clean:
	rm -rf $(RESULTS)
