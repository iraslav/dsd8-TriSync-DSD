# =============================================================================
# Makefile for DSD-8 Processor Project
# =============================================================================

PYTHON ?= python

.PHONY: all test conformance wave clean lint help

help:
	@echo "Available targets:"
	@echo "  make all          - Run unit tests and all 40 conformance tests"
	@echo "                      (waveforms auto-created in sim/waves/ on every run)"
	@echo "  make test         - Run all self-checking unit testbenches"
	@echo "  make conformance  - Run the full 40-test conformance suite"
	@echo "  make wave         - Waveform: compile+simulate and open GTKWave"
	@echo "                      make wave TB=tb_alu"
	@echo "                      make wave TB=tb_dsd8 TEST=T36"
	@echo "                      make wave TB=tb_dsd8 ASM=bubblesort"
	@echo "  make lint         - Check syntax of all RTL modules"
	@echo "  make clean        - Remove compiled .vvp, .vcd, and temporary trace files"

all:
	$(PYTHON) scripts/run_all.py

test:
	$(PYTHON) -c "import sys, os; sys.path.insert(0, '.'); from scripts.run_all import run_unit_tests; sys.exit(0 if run_unit_tests() else 1)"

conformance:
	$(PYTHON) -c "import sys, os; sys.path.insert(0, '.'); from scripts.run_all import run_conformance_suite; sys.exit(0 if run_conformance_suite() else 1)"

wave:
	$(if $(TB),,$(error Usage: make wave TB=tb_alu [TEST=T01 | ASM=multiply]))
	$(PYTHON) scripts/run_wave.py $(TB) $(if $(TEST),--test $(TEST),) $(if $(ASM),--asm $(ASM),)

lint:
	@echo "Checking syntax of all RTL modules..."
	tools/iverilog/app/bin/iverilog.exe -g2012 -t null $(wildcard rtl/*.v)
	@echo "Lint check completed successfully with 0 errors!"

clean:
	$(PYTHON) -c "import glob, os, shutil; [os.remove(p) for p in glob.glob('sim/*.vvp') + glob.glob('sim/*.trace') + glob.glob('sim/*.vcd')]; shutil.rmtree('sim/waves', ignore_errors=True)"
