# tb/ -- testbenches

## `tb_dsd8.v` -- the conformance harness

This is "the supplied harness" from Section 8.3 of the spec. It is run
by `scripts/run_conformance.py`, not by hand, and you do not modify it
-- everyone is graded against the same file. See the comments at the
top of `tb_dsd8.v` for exactly what it wires up.

## Your own unit testbenches (Section 8.5, R24)

Every module in `rtl/` needs its own self-checking testbench, written
by its owner. `tb_alu_example.v` is a worked example of the pattern:

1. Instantiate the DUT.
2. Compute the expected result **independently** -- do not copy the
   DUT's own logic into the testbench, or a bug you make once will
   agree with itself twice.
3. Apply a set of vectors (directed for a first pass; the ALU
   additionally needs a **constrained-random** loop of at least 10,000
   operand pairs per R24, covering the corner-case operands in R25).
4. Count mismatches and print exactly one final line:
   `TESTBENCH: PASS` or `TESTBENCH: FAIL (N errors)`.

`scripts/run_unit_tests.py` looks for those two exact strings on
stdout -- keep the convention in every testbench you add, and name
files `tb_<module>.v` so the script finds them automatically.

`tb_alu_example.v` will **fail** against the placeholder `alu.v` in
this template. That is correct: the module is not implemented yet.
