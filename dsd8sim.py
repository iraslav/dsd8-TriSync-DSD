#!/usr/bin/env python3
"""
DSD-8 Golden Reference Simulator (dsd8sim.py)
Simulates DSD-8 machine code and produces execution traces per Section 8.2.
"""

import sys
import argparse

class DSD8Simulator:
    def __init__(self, imem_hex_path=None, max_cycles=100000):
        self.pc = 0              # 9-bit PC (0..511)
        self.regs = [0] * 8      # 8-bit registers R0..R7
        self.dmem = [0] * 256    # 8-bit data memory (0x00..0xFF)
        self.imem = [0] * 512    # 16-bit instruction memory (0x000..0x1FF)
        self.flag_z = 0
        self.flag_n = 0
        self.flag_c = 0
        self.flag_v = 0
        self.halted = False
        self.seq = 1
        self.trace_lines = []
        self.max_cycles = max_cycles
        
        # IO space
        self.ports = [0] * 256
        self.io_writes = []

        if imem_hex_path:
            self.load_hex(imem_hex_path)

    def load_hex(self, path):
        with open(path, 'r') as f:
            lines = [line.strip() for line in f if line.strip() and not line.startswith('//')]
        for i, line in enumerate(lines):
            if i < 512:
                # Can be a single hex word
                word_str = line.split()[0]
                self.imem[i] = int(word_str, 16) & 0xFFFF

    def get_flags_str(self):
        return f"{self.flag_z}{self.flag_n}{self.flag_c}{self.flag_v}"

    def step(self):
        if self.halted:
            return False

        cur_pc = self.pc
        ir = self.imem[cur_pc]

        opcode = (ir >> 12) & 0xF
        rd     = (ir >> 9)  & 0x7
        rs1    = (ir >> 6)  & 0x7
        rs2    = (ir >> 3)  & 0x7
        imm8   = ir & 0xFF
        port8  = ir & 0xFF
        addr9  = ir & 0x1FF
        cond   = (ir >> 9)  & 0x7
        io_dir = (ir >> 8)  & 0x1

        # Defaults for trace
        rf_we = 0
        rf_addr = 0
        rf_data = 0
        mem_we = 0
        mem_addr = 0
        mem_data = 0

        next_pc = (cur_pc + 1) & 0x1FF

        if opcode == 0x0: # NOP
            pass

        elif opcode == 0x1: # LDI rd, imm8
            self.regs[rd] = imm8
            rf_we = 1
            rf_addr = rd
            rf_data = imm8

        elif opcode == 0x2: # LD rd, [rs1]
            addr = self.regs[rs1]
            val = self.dmem[addr]
            self.regs[rd] = val
            rf_we = 1
            rf_addr = rd
            rf_data = val

        elif opcode == 0x3: # ST [rs1], rs2
            addr = self.regs[rs1]
            val = self.regs[rd]  # In Format M, data to store comes from rd/rs2 field (ir[11:9])
            self.dmem[addr] = val
            mem_we = 1
            mem_addr = addr
            mem_data = val

        elif opcode in (0x4, 0x5, 0x6, 0x7, 0x8, 0x9, 0xA, 0xB): # ALU operations
            a = self.regs[rs1]
            b = self.regs[rs2]
            res = 0
            carry = 0
            overflow = 0

            if opcode == 0x4: # ADD
                sum9 = a + b
                res = sum9 & 0xFF
                carry = 1 if sum9 > 0xFF else 0
                overflow = 1 if (((a ^ res) & (b ^ res) & 0x80) != 0) else 0

            elif opcode == 0x5 or opcode == 0xB: # SUB or CMP
                diff = a - b
                res = diff & 0xFF
                carry = 1 if a >= b else 0  # C=1 means no borrow (a >= b)
                overflow = 1 if (((a ^ b) & (a ^ res) & 0x80) != 0) else 0

            elif opcode == 0x6: # AND
                res = a & b
                carry = 0
                overflow = 0

            elif opcode == 0x7: # OR
                res = a | b
                carry = 0
                overflow = 0

            elif opcode == 0x8: # XOR
                res = a ^ b
                carry = 0
                overflow = 0

            elif opcode == 0x9: # SHL
                res = (a << 1) & 0xFF
                carry = (a >> 7) & 1
                overflow = 0

            elif opcode == 0xA: # SHR (logical)
                res = (a >> 1) & 0xFF
                carry = a & 1
                overflow = 0

            # Update flags
            self.flag_z = 1 if res == 0 else 0
            self.flag_n = (res >> 7) & 1
            self.flag_c = carry
            self.flag_v = overflow

            if opcode != 0xB: # CMP does not write register
                self.regs[rd] = res
                rf_we = 1
                rf_addr = rd
                rf_data = res

        elif opcode == 0xC: # JMP addr9
            next_pc = addr9

        elif opcode == 0xD: # Bcc addr9
            taken = False
            if cond == 0:   taken = (self.flag_z == 1)       # BEQ
            elif cond == 1: taken = (self.flag_z == 0)       # BNE
            elif cond == 2: taken = (self.flag_c == 1)       # BCS
            elif cond == 3: taken = (self.flag_c == 0)       # BCC
            elif cond == 4: taken = (self.flag_n == 1)       # BMI
            elif cond == 5: taken = (self.flag_n == 0)       # BPL
            elif cond == 6: taken = (self.flag_v == 1)       # BVS
            elif cond == 7: taken = (self.flag_v == 0)       # BVC

            if taken:
                next_pc = addr9

        elif opcode == 0xE: # IN / OUT
            if io_dir == 0: # IN rd, port
                val = self.ports[port8]
                self.regs[rd] = val
                rf_we = 1
                rf_addr = rd
                rf_data = val
            else: # OUT port, rs
                val = self.regs[rd]
                self.ports[port8] = val
                self.io_writes.append((port8, val))

        elif opcode == 0xF: # HLT
            self.halted = True

        # Rule R23: Fields 5, 6, 8, 9 shall be zero whenever write-enable is zero
        if rf_we == 0:
            rf_addr = 0
            rf_data = 0
        if mem_we == 0:
            mem_addr = 0
            mem_data = 0

        # Trace line format per Section 8.2:
        # 1: seq (%04d)
        # 2: pc (%03X)
        # 3: ir (%04X)
        # 4: rf_we (%01d)
        # 5: rf_addr (%01d)
        # 6: rf_data (%02X)
        # 7: mem_we (%01d)
        # 8: mem_addr (%02X)
        # 9: mem_data (%02X)
        # 10: flags (%01d%01d%01d%01d)
        trace_line = (
            f"{self.seq:04d} {cur_pc:03X} {ir:04X} "
            f"{rf_we:01d} {rf_addr:01d} {rf_data:02X} "
            f"{mem_we:01d} {mem_addr:02X} {mem_data:02X} "
            f"{self.get_flags_str()}"
        )
        self.trace_lines.append(trace_line)
        self.seq += 1

        if not self.halted:
            self.pc = next_pc

        return not self.halted

    def run(self):
        cycles = 0
        while not self.halted and cycles < self.max_cycles:
            self.step()
            cycles += 1
        return cycles

def main():
    parser = argparse.ArgumentParser(description="DSD-8 Reference Simulator")
    parser.add_argument("hexfile", help="Program hex file")
    parser.add_argument("-t", "--trace", help="Output golden trace file", default=None)
    parser.add_argument("-m", "--max-cycles", type=int, default=100000, help="Max cycle limit")
    args = parser.parse_args()

    sim = DSD8Simulator(args.hexfile, max_cycles=args.max_cycles)
    cycles = sim.run()

    if args.trace:
        with open(args.trace, 'w') as f:
            for l in sim.trace_lines:
                f.write(l + '\n')
        print(f"Simulation completed in {cycles} instructions ({len(sim.trace_lines)} retired). Trace written to '{args.trace}'")
    else:
        for l in sim.trace_lines[:15]:
            print(l)
        if len(sim.trace_lines) > 15:
            print(f"... ({len(sim.trace_lines) - 15} more lines)")
        print(f"Total instructions retired: {len(sim.trace_lines)}")

if __name__ == '__main__':
    main()
