#!/usr/bin/env python3
"""
dsd8sim.py -- the golden reference simulator for the DSD-8 ISA
(DSD-8 Processor Project Specification, Sections 2-3 and 8).

This is the "ground truth" your RTL is graded against: it executes a
.hex program instruction-by-instruction and emits one trace line per
retired instruction, in exactly the ten-field format described in
Section 8.2. scripts/run_conformance.py diffs this against the trace
your dsd8_cpu produces in simulation.

This file is meant to be read, not just run -- if you are unsure what
an instruction is supposed to do to the flags, this is the definition.

Usage:
    python3 dsd8sim.py program.hex --trace gold.trace
    python3 dsd8sim.py program.hex --trace gold.trace --state-out state.json

Simplifications (documented, not hidden):
  - I/O ports are modelled functionally, not cycle-accurately: every
    IN/OUT is treated as completing immediately. The trace format has
    no notion of wall-clock time, so this cannot change a correct
    trace -- it only means this simulator does not reproduce the
    io_ready stall itself (your RTL testbench must still exercise that
    with SLOW_ECHO; see sim/peripherals.v).
  - Unfilled instruction memory reads as 0x0000 (NOP), never X.
"""
import argparse
import json
import sys

IMEM_WORDS = 512
DMEM_BYTES = 256


class Cpu:
    def __init__(self, imem, switches=0, buttons=0):
        self.imem = imem
        self.r = [0] * 8
        self.dmem = [0] * DMEM_BYTES
        self.z = self.n = self.c = self.v = 0
        self.pc = 0
        self.halted = False
        self.seq = 1

        # board / peripheral state (Section 7.2 standard port map)
        self.switches = switches & 0xFF
        self.buttons = buttons & 0x1F
        self.leds = 0
        self.seg_value = 0
        self.seg_enable = 0
        self.uart_tx_log = []
        self.uart_rx_queue = []
        self.timer_count = 0
        self.timer_enable = 0
        self.slow_echo_last = 0

    # ---- I/O bus model (Section 7.2) ----
    def io_read(self, port):
        if port == 0x00:
            return self.switches
        if port == 0x01:
            return self.buttons & 0x1F
        if port == 0x21:
            return self.uart_rx_queue.pop(0) if self.uart_rx_queue else 0x00
        if port == 0x22:
            rx_valid = 1 if self.uart_rx_queue else 0
            return (rx_valid << 1) | 0  # tx_busy always 0 in this model
        if port == 0x30:
            return self.timer_count & 0xFF
        if port == 0x40:
            return self.slow_echo_last
        return 0x00  # unmapped port reads return 0x00

    def io_write(self, port, val):
        val &= 0xFF
        if port == 0x02:
            self.leds = val
        elif port == 0x10:
            self.seg_value = val
        elif port == 0x11:
            self.seg_enable = val
        elif port == 0x20:
            self.uart_tx_log.append(val)
        elif port == 0x31:
            self.timer_enable = val & 0x1
            if val & 0x2:
                self.timer_count = 0
        elif port == 0x40:
            self.slow_echo_last = val
        # writes to any other port (including reserved 0x00-0x1F gaps) are discarded

    # ---- one instruction ----
    def step(self):
        """Execute one instruction. Returns a trace-line dict, or None if halted."""
        if self.halted:
            return None

        pc_this = self.pc
        ir = self.imem[pc_this] & 0xFFFF
        opcode = (ir >> 12) & 0xF
        fa = (ir >> 9) & 0x7     # rd, or the ST/OUT source register
        fb = (ir >> 6) & 0x7     # rs1
        fc = (ir >> 3) & 0x7     # rs2
        imm8 = ir & 0xFF
        addr9 = ir & 0x1FF
        dir_bit = (ir >> 8) & 0x1

        rf_we = 0
        rf_addr = 0
        rf_data = 0
        mem_we = 0
        mem_addr = 0
        mem_data = 0
        flags_changed = False
        pc_next = (pc_this + 1) & 0x1FF

        if opcode == 0x0:  # NOP
            pass

        elif opcode == 0x1:  # LDI rd, imm8
            rf_we, rf_addr, rf_data = 1, fa, imm8
            self.r[fa] = imm8

        elif opcode == 0x2:  # LD rd, [rs1]
            addr = self.r[fb]
            val = self.dmem[addr]
            rf_we, rf_addr, rf_data = 1, fa, val
            self.r[fa] = val

        elif opcode == 0x3:  # ST [rs1], rs2   (rs2 lives in the 'fa' field)
            addr = self.r[fb]
            val = self.r[fa]
            self.dmem[addr] = val
            mem_we, mem_addr, mem_data = 1, addr, val

        elif opcode in (0x4, 0x5):  # ADD / SUB
            a, b = self.r[fb], self.r[fc]
            if opcode == 0x4:
                total = a + b
                result = total & 0xFF
                carry = 1 if total > 0xFF else 0
                same_sign_in = ((a >> 7) & 1) == ((b >> 7) & 1)
            else:
                total = a - b
                result = total & 0xFF
                carry = 1 if a >= b else 0  # DSD-8 convention: C=1 means NO borrow
                same_sign_in = ((a >> 7) & 1) != ((b >> 7) & 1)
            overflow = 1 if same_sign_in and (((result >> 7) & 1) != ((a >> 7) & 1)) else 0
            self.r[fa] = result
            rf_we, rf_addr, rf_data = 1, fa, result
            self.z, self.n, self.c, self.v = int(result == 0), (result >> 7) & 1, carry, overflow
            flags_changed = True

        elif opcode in (0x6, 0x7, 0x8):  # AND / OR / XOR
            a, b = self.r[fb], self.r[fc]
            if opcode == 0x6:
                result = a & b
            elif opcode == 0x7:
                result = a | b
            else:
                result = a ^ b
            self.r[fa] = result
            rf_we, rf_addr, rf_data = 1, fa, result
            self.z, self.n, self.c, self.v = int(result == 0), (result >> 7) & 1, 0, 0
            flags_changed = True

        elif opcode == 0x9:  # SHL rd, rs1
            a = self.r[fb]
            carry = (a >> 7) & 1
            result = (a << 1) & 0xFF
            self.r[fa] = result
            rf_we, rf_addr, rf_data = 1, fa, result
            self.z, self.n, self.c, self.v = int(result == 0), (result >> 7) & 1, carry, 0
            flags_changed = True

        elif opcode == 0xA:  # SHR rd, rs1 -- logical, zero into bit 7
            a = self.r[fb]
            carry = a & 1
            result = (a >> 1) & 0x7F
            self.r[fa] = result
            rf_we, rf_addr, rf_data = 1, fa, result
            self.z, self.n, self.c, self.v = int(result == 0), (result >> 7) & 1, carry, 0
            flags_changed = True

        elif opcode == 0xB:  # CMP rs1, rs2 -- sets flags, writes nothing
            a, b = self.r[fb], self.r[fc]
            total = a - b
            result = total & 0xFF
            carry = 1 if a >= b else 0
            same_sign_in = ((a >> 7) & 1) != ((b >> 7) & 1)
            overflow = 1 if same_sign_in and (((result >> 7) & 1) != ((a >> 7) & 1)) else 0
            self.z, self.n, self.c, self.v = int(result == 0), (result >> 7) & 1, carry, overflow
            flags_changed = True

        elif opcode == 0xC:  # JMP addr9
            pc_next = addr9

        elif opcode == 0xD:  # Bcc addr9 -- tests the CURRENT flags, unmodified
            cond = fa
            taken = {
                0b000: self.z == 1,        # BEQ
                0b001: self.z == 0,        # BNE
                0b010: self.c == 1,        # BCS
                0b011: self.c == 0,        # BCC
                0b100: self.n == 1,        # BMI
                0b101: self.n == 0,        # BPL
                0b110: self.v == 1,        # BVS
                0b111: self.v == 0,        # BVC
            }[cond]
            if taken:
                pc_next = addr9

        elif opcode == 0xE:  # IN / OUT
            port = imm8
            if dir_bit == 0:  # IN rd, port
                val = self.io_read(port)
                self.r[fa] = val
                rf_we, rf_addr, rf_data = 1, fa, val
            else:  # OUT port, rs
                self.io_write(port, self.r[fa])

        elif opcode == 0xF:  # HLT
            self.halted = True

        else:
            raise ValueError(f"illegal opcode 0x{opcode:X} at pc=0x{pc_this:03X} (spec defines all 16)")

        flags_after = (self.z << 3) | (self.n << 2) | (self.c << 1) | self.v

        line = {
            "seq": self.seq,
            "pc": pc_this,
            "ir": ir,
            "rf_we": rf_we, "rf_addr": rf_addr, "rf_data": rf_data,
            "mem_we": mem_we, "mem_addr": mem_addr, "mem_data": mem_data,
            "z": self.z, "n": self.n, "c": self.c, "v": self.v,
        }
        self.seq += 1
        self.pc = pc_next
        return line


def format_trace_line(t):
    return "{seq:04d} {pc:03x} {ir:04x} {rf_we:01d} {rf_addr:01d} {rf_data:02x} " \
           "{mem_we:01d} {mem_addr:02x} {mem_data:02x} {z:01d}{n:01d}{c:01d}{v:01d}".format(**t)


def load_hex(path):
    words = [0] * IMEM_WORDS
    with open(path) as f:
        i = 0
        for raw in f:
            tok = raw.strip()
            if not tok or tok.startswith("//"):
                continue
            words[i] = int(tok, 16) & 0xFFFF
            i += 1
            if i >= IMEM_WORDS:
                break
    return words


def run(hex_path, max_instrs=100000, switches=0, buttons=0):
    imem = load_hex(hex_path)
    cpu = Cpu(imem, switches=switches, buttons=buttons)
    trace_lines = []
    hit_limit = False
    for _ in range(max_instrs):
        line = cpu.step()
        if line is None:
            break
        trace_lines.append(line)
    else:
        hit_limit = not cpu.halted

    state = {
        "registers": cpu.r,
        "flags": {"Z": cpu.z, "N": cpu.n, "C": cpu.c, "V": cpu.v},
        "halted": cpu.halted,
        "instructions_retired": len(trace_lines),
        "leds": cpu.leds,
        "seg_value": cpu.seg_value,
        "seg_enable": cpu.seg_enable,
        "uart_tx": cpu.uart_tx_log,
        "dmem_nonzero": {i: b for i, b in enumerate(cpu.dmem) if b != 0},
        "hit_instruction_limit": hit_limit,
    }
    return trace_lines, state


def main():
    ap = argparse.ArgumentParser(description="DSD-8 golden reference simulator")
    ap.add_argument("hex", help="input program.hex ($readmemh format)")
    ap.add_argument("--trace", required=True, help="output trace file")
    ap.add_argument("--state-out", help="optional JSON file with final architectural state")
    ap.add_argument("--max-instrs", type=int, default=100000,
                     help="safety limit for non-halting programs (default 100000)")
    ap.add_argument("--switches", type=lambda s: int(s, 0), default=0, help="initial SWITCHES value")
    ap.add_argument("--buttons", type=lambda s: int(s, 0), default=0, help="initial BUTTONS value")
    args = ap.parse_args()

    trace_lines, state = run(args.hex, args.max_instrs, args.switches, args.buttons)

    with open(args.trace, "w") as f:
        for t in trace_lines:
            f.write(format_trace_line(t) + "\n")

    if args.state_out:
        with open(args.state_out, "w") as f:
            json.dump(state, f, indent=2)

    print(f"retired {len(trace_lines)} instructions -> {args.trace}"
          + (" (hit instruction limit, did not halt)" if state["hit_instruction_limit"] else ""))


if __name__ == "__main__":
    main()
