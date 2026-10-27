#!/usr/bin/env python3
"""
DSD-8 Assembler (dsd8asm.py)
Assembles DSD-8 assembly programs into 16-bit hex machine code.
Specification version 1.0.
"""

import sys
import re
import argparse

COND_MAP = {
    'BEQ': 0,
    'BNE': 1,
    'BCS': 2,
    'BCC': 3,
    'BMI': 4,
    'BPL': 5,
    'BVS': 6,
    'BVC': 7,
}

OPCODE_MAP = {
    'NOP': 0x0,
    'LDI': 0x1,
    'LD':  0x2,
    'ST':  0x3,
    'ADD': 0x4,
    'SUB': 0x5,
    'AND': 0x6,
    'OR':  0x7,
    'XOR': 0x8,
    'SHL': 0x9,
    'SHR': 0xA,
    'CMP': 0xB,
    'JMP': 0xC,
    'IN':  0xE,
    'OUT': 0xE,
    'HLT': 0xF,
}

def parse_reg(s):
    s = s.strip().upper()
    if s.startswith('R') and s[1:].isdigit():
        r = int(s[1:])
        if 0 <= r <= 7:
            return r
    raise ValueError(f"Invalid register name: {s}")

def parse_val(s, labels, max_val=0xFF):
    s = s.strip()
    if s in labels:
        val = labels[s]
    elif s.startswith('0x') or s.startswith('0X'):
        val = int(s, 16)
    elif s.startswith('0b') or s.startswith('0B'):
        val = int(s, 2)
    elif s.isdigit() or (s.startswith('-') and s[1:].isdigit()):
        val = int(s, 10)
    else:
        raise ValueError(f"Unknown value or undefined label: {s}")
    return val

def strip_brackets(s):
    s = s.strip()
    if s.startswith('[') and s.endswith(']'):
        return s[1:-1].strip()
    return s

def assemble(lines):
    # Pass 1: Remove comments, strip whitespace, collect labels
    cleaned = []
    labels = {}
    addr = 0

    for raw_line in lines:
        line = raw_line.split(';')[0].strip()
        if not line:
            continue

        # Check for labels (possibly multiple or preceding instruction)
        while ':' in line:
            parts = line.split(':', 1)
            lbl = parts[0].strip()
            if lbl:
                if lbl in labels:
                    raise ValueError(f"Duplicate label: {lbl}")
                labels[lbl] = addr
            line = parts[1].strip()

        if line:
            cleaned.append((addr, line))
            addr += 1

    # Pass 2: Encode instructions
    encoded = []
    for pc, line in cleaned:
        tokens = [t.strip() for t in re.split(r'[\s,]+', line) if t.strip()]
        if not tokens:
            continue

        mnemonic = tokens[0].upper()
        args = tokens[1:]

        # Handle aliases / pseudo-ops
        if mnemonic == 'MOV':
            # MOV rd, rs -> OR rd, rs, rs
            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            code = (0x7 << 12) | (rd << 9) | (rs << 6) | (rs << 3)
            encoded.append((pc, code, line))
            continue

        if mnemonic == 'NOT':
            # NOT rd, rs, rmask -> XOR rd, rs, rmask
            rd = parse_reg(args[0])
            rs = parse_reg(args[1])
            rmask = parse_reg(args[2])
            code = (0x8 << 12) | (rd << 9) | (rs << 6) | (rmask << 3)
            encoded.append((pc, code, line))
            continue

        if mnemonic == 'NOP':
            code = 0x0000
        elif mnemonic == 'HLT':
            code = 0xF000
        elif mnemonic == 'LDI':
            rd = parse_reg(args[0])
            imm = parse_val(args[1], labels, max_val=0xFF) & 0xFF
            code = (0x1 << 12) | (rd << 9) | imm
        elif mnemonic == 'LD':
            rd = parse_reg(args[0])
            rs1_str = strip_brackets(args[1])
            rs1 = parse_reg(rs1_str)
            code = (0x2 << 12) | (rd << 9) | (rs1 << 6)
        elif mnemonic == 'ST':
            # ST [rs1], rs2  -- rs1=addr, rs2=data
            rs1_str = strip_brackets(args[0])
            rs1 = parse_reg(rs1_str)
            rs2 = parse_reg(args[1])
            code = (0x3 << 12) | (rs2 << 9) | (rs1 << 6)
        elif mnemonic in ('ADD', 'SUB', 'AND', 'OR', 'XOR'):
            op = OPCODE_MAP[mnemonic]
            rd = parse_reg(args[0])
            rs1 = parse_reg(args[1])
            rs2 = parse_reg(args[2])
            code = (op << 12) | (rd << 9) | (rs1 << 6) | (rs2 << 3)
        elif mnemonic in ('SHL', 'SHR'):
            op = OPCODE_MAP[mnemonic]
            rd = parse_reg(args[0])
            rs1 = parse_reg(args[1])
            code = (op << 12) | (rd << 9) | (rs1 << 6)
        elif mnemonic == 'CMP':
            rs1 = parse_reg(args[0])
            rs2 = parse_reg(args[1])
            code = (0xB << 12) | (0 << 9) | (rs1 << 6) | (rs2 << 3)
        elif mnemonic == 'JMP':
            target = parse_val(args[0], labels, max_val=0x1FF) & 0x1FF
            code = (0xC << 12) | target
        elif mnemonic in COND_MAP:
            cond = COND_MAP[mnemonic]
            target = parse_val(args[0], labels, max_val=0x1FF) & 0x1FF
            code = (0xD << 12) | (cond << 9) | target
        elif mnemonic == 'IN':
            rd = parse_reg(args[0])
            port = parse_val(args[1], labels, max_val=0xFF) & 0xFF
            code = (0xE << 12) | (rd << 9) | (0 << 8) | port
        elif mnemonic == 'OUT':
            port = parse_val(args[0], labels, max_val=0xFF) & 0xFF
            rs = parse_reg(args[1])
            code = (0xE << 12) | (rs << 9) | (1 << 8) | port
        else:
            raise ValueError(f"Unknown instruction '{mnemonic}' at line: {line}")

        encoded.append((pc, code, line))

    return encoded

def write_hex(encoded, filename, pad_to=512):
    mem = [0x0000] * pad_to
    for pc, code, _ in encoded:
        if pc < pad_to:
            mem[pc] = code
    with open(filename, 'w') as f:
        for val in mem:
            f.write(f"{val:04X}\n")

def main():
    parser = argparse.ArgumentParser(description="DSD-8 Assembler")
    parser.add_argument("input", help="Source .asm file")
    parser.add_argument("-o", "--output", help="Output .hex file", default=None)
    parser.add_argument("-v", "--verbose", action="store_true", help="Print disassembly listing")
    args = parser.parse_args()

    out_file = args.output
    if not out_file:
        out_file = args.input.rsplit('.', 1)[0] + '.hex'

    with open(args.input, 'r', encoding='utf-8') as f:
        lines = f.readlines()

    encoded = assemble(lines)
    write_hex(encoded, out_file)

    if args.verbose:
        for pc, code, text in encoded:
            print(f"{pc:03X}: {code:04X}    {text}")
    print(f"Assembled {len(encoded)} instructions into '{out_file}'")

if __name__ == '__main__':
    main()
