# DSD-8 Processor -- starter repository

Base code for the DSD-8 Processor project (Digital System Design). This
repository is the CI/certification and verification infrastructure the
project needs -- it is **not** a working processor. Every module under
`rtl/` is an unimplemented placeholder with the frozen port list from
Section 5 and a `TODO`; writing the actual RTL is the assignment.

## What's here

```
rtl/        module skeletons -- frozen ports, no behaviour yet (yours to write)
tb/         tb_dsd8.v (the supplied conformance harness, do not edit)
            + tb_alu_example.v (a worked example of a self-checking testbench)
sim/        instructor-supplied reference peripheral models (UART, timer, SLOW_ECHO)
tools/      dsd8asm.py (assembler) and dsd8sim.py (golden reference simulator)
tests/conformance/   two verified sample programs (see its README) --
            drop the real T01-T40 suite in here when it's distributed
scripts/    run_conformance.py, run_unit_tests.py, lint.sh, install_hooks.sh
doc/        design report / verification report / bug log templates
.github/    CI workflows, CODEOWNERS, PR and issue templates
```

## Quick start

```
git clone <your-team's-repo-url>
cd <repo>
./scripts/install_hooks.sh      # certify locally before every push
make lint                       # verilator --lint-only (needs verilator)
make test                       # every tb/tb_*.v unit testbench (needs iverilog)
make conformance                # tests/conformance/*.asm end to end
```

`make conformance` should work out of the box against the placeholder
RTL -- it will report both sample programs as **FAIL**, because
`dsd8_cpu`'s `retire` output is tied low in the placeholder (nothing is
emitted). That failure, cleanly reported with a diff, is the point:
the certification pipeline is what you are handed on day one, not
something you build at the end.

## The four things this template gives you that the spec describes but
## does not hand you the source of

1. **`tools/dsd8asm.py` / `tools/dsd8sim.py`** -- a real assembler and
   golden reference simulator implementing the full ISA (Sections 2-3),
   verified against the two fully-specified worked examples in
   Appendix B. This is what `dsd8sim.py` means everywhere the spec
   refers to "the reference simulator."
2. **`tb/tb_dsd8.v`** -- the harness described in Section 8.3, wired to
   `dsd8_cpu` + `instr_memory` + `io_bus` and emitting the exact
   ten-field trace format from Section 8.2.
3. **`sim/peripherals.v`** -- the reference UART/timer/SLOW_ECHO models
   Section 7.2 says are supplied, so a peripheral bug is never mistaken
   for a CPU bug (with two documented simplifications -- see the file).
4. **`scripts/run_conformance.py`** -- diffs your trace against the
   golden one and reports the first differing line, which is the whole
   verification methodology in Section 8.1 as one command.

See `README` files in `tb/` and `tests/conformance/` for more detail,
and the project doc "DSD-8 Processor -- GitHub Classroom & CI
Certification Plan" for the instructor-facing setup (GitHub Classroom,
branch protection, milestone tags, mark allocation).

## Workflow, in one paragraph

Branch per module or feature, PR into `main`, CI lints and unit-tests
on every push (conformance reports but doesn't gate), your module's
owner approves via CODEOWNERS, merge. At each milestone deadline, tag
the commit (`git tag m3 && git push --tags`) -- grading always reads
the tagged commit, and pushing a milestone tag makes conformance
authoritative for that ref. Full detail in `CONTRIBUTING.md`.
