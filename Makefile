# Makefile -- the four commands that certify this repository.
#
#   make lint         verilator --lint-only on rtl/ (no inferred latches, etc.)
#   make test         every unit testbench under tb/ (tb_*.v except tb_dsd8.v)
#   make conformance  the full conformance suite (tests/conformance/*.asm)
#   make all          lint + test + conformance, in that order
#
# CI (.github/workflows/ci.yml) runs these same targets, so what passes
# here passes there. The pre-push hook (githooks/pre-push, installed by
# scripts/install_hooks.sh) runs `lint` and `test` before every push.

PYTHON ?= python3

.PHONY: all lint test conformance clean

all: lint test conformance

lint:
	./scripts/lint.sh

test:
	$(PYTHON) scripts/run_unit_tests.py

conformance:
	$(PYTHON) scripts/run_conformance.py

clean:
	rm -rf build
