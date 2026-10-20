# Verification report

*Team: _____ &nbsp;&nbsp; Members: _____ &nbsp;&nbsp; Date: _____*

*Target length: 4-6 pages (Section 9.3, item 3). Delete this line and
the prompts below once you've written the real content.*

## 1. Test plan

What you set out to verify, and in what order. (The recommended order
of attack -- NOP, then register writeback, then JMP, then everything
else -- is a reasonable spine for this section, but describe what you
actually did.)

## 2. Unit testbench coverage

For each module in `rtl/`: what its testbench checks, and what it
deliberately does not.

| Module | Testbench | What it covers | Known gaps |
|--------|-----------|-----------------|------------|
| alu | tb/tb_alu.v | | |
| register_file | | | |
| ... | | | |

## 3. ALU random test and coverage evidence

Required by R24/R25. Report:
- number of random operand pairs exercised (>= 10,000),
- confirmation that 0x00, 0x01, 0x7F, 0x80, 0xFF occurred as **both**
  operands (paste the coverage evidence, not just an assertion that it
  happened),
- any mismatches found and how they were resolved.

## 4. Conformance results

Final `make conformance` score, and for any historical failures, what
they were and how they were root-caused (link bug log entries).

## 5. Closure argument

Why the remaining risk -- whatever you did *not* verify -- is
acceptable. This is the section an examiner will push hardest on at
the oral defence; a confident "we didn't test X because Y" is a much
stronger answer than pretending coverage is complete.

## 6. Bug log summary

Link to `doc/bug_log_template.md` (filled in), plus one paragraph on
the found-by pattern your own data shows.
