# Design report

*Team: _____ &nbsp;&nbsp; Members: _____ &nbsp;&nbsp; Date: _____*

*Target length: 6-10 pages (Section 9.3, item 4). Delete this line and
the prompts below once you've written the real content.*

## 1. Microarchitecture

Single-cycle, multi-cycle, or pipelined (Section 4.3) -- which you
chose, and why. If multi-cycle, your state machine (a diagram, plus
prose); if pipelined, your hazard handling.

## 2. Control-signal table, as implemented

Reproduce Section 6.2's table with your own state/cycle numbers, for
every opcode. Where you deviate from the recommended structure, say so
and why.

## 3. Module-by-module notes

Anything about `rtl/*.v` worth explaining that is not obvious from the
code and comments: non-obvious timing, anything you built differently
from the frozen interfaces would suggest, how `data_memory`'s reset (it
has no rst_n of its own -- see `rtl/data_memory.v`) was handled.

## 4. Design-decision record

At least five decisions, each with the alternative(s) you rejected and
why. Good candidates: how `data_memory` gets cleared without an
`rst_n` pin; how you built `SHR`'s arithmetic-shift cousin for T22
without an instruction for it; anything your `io_bus` does that this
template's placeholder didn't dictate for you.

| # | Decision | Alternative(s) considered | Why this one |
|---|----------|----------------------------|----------------|
| 1 | | | |
| 2 | | | |
| 3 | | | |
| 4 | | | |
| 5 | | | |

## 5. What this project cost you

Section 3.6's closing note is a fair prompt to answer here: what did
the instruction set's omissions (no add-immediate, no register move, no
subroutine call, no stack) actually cost you in an instruction count or
a register you'd rather have had free? Concrete beats general.
