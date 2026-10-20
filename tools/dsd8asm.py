#!/usr/bin/env python3
"""
dsd8asm.py -- a small two-pass assembler for the DSD-8 instruction set
(DSD-8 Processor Project Specification, Section 3).

This is base/reference code, provided so that teams and the grading
pipeline share one unambiguous definition of "what this assembly means".
It is deliberately small and readable rather than clever -- read it if
you are unsure how an instruction encodes.

Usage:
    python3 dsd8asm.py program.asm -o program.hex [--listing program.lst]

Output .hex format matches Verilog $readmemh: one 4-digit hex word per
line, in address order starting at address 0. This is what your
instr_memory module's IMAGE parameter should point to.
"""
import argparse
import re
import sys

REGISTERS = {f"R{i}": i for i in range(8)}
REGISTERS.update({f"r{i}": i for i in range(8)})

# opcode -> (mnemonic, format)
OPCODES = {
    "NOP": (0x0, "NONE"),
    "LDI": (0x1, "I"),
    "LD":  (0x2, "M_LD"),
    "ST":  (0x3, "M_ST"),
    "ADD": (0x4, "R3"),
    "SUB": (0x5, "R3"),
    "AND": (0x6, "R3"),
    "OR":  (0x7, "R3"),
    "XOR": (0x8, "R3"),
    "SHL": (0x9, "R2"),
    "SHR": (0xA, "R2"),
    "CMP": (0xB, "R2CMP"),
    "JMP": (0xC, "J"),
    "IN":  (0xE, "P_IN"),
    "OUT": (0xE, "P_OUT"),
    "HLT": (0xF, "NONE"),
}

# branch mnemonic -> 3-bit cond field (Section 3.3 / Appendix A)
BRANCHES = {
    "BEQ": 0b000, "BNE": 0b001,
    "BCS": 0b010, "BCC": 0b011,
    "BMI": 0b100, "BPL": 0b101,
    "BVS": 0b110, "BVC": 0b111,
}


class AsmError(Exception):
    def __init__(self, line_no, msg):
        super().__init__(f"line {line_no}: {msg}")
        self.line_no = line_no


def strip_comment(line):
    idx = line.find(";")
    return line if idx < 0 else line[:idx]


def parse_reg(tok, line_no):
    tok = tok.strip()
    if tok not in REGISTERS:
        raise AsmError(line_no, f"expected a register (R0..R7), got '{tok}'")
    return REGISTERS[tok]


def parse_imm(tok, line_no, bits, labels=None):
    tok = tok.strip()
    if labels is not None and tok in labels:
        val = labels[tok]
    else:
        try:
            val = int(tok, 0)  # accepts 0x.., 0b.., or decimal
        except ValueError:
            raise AsmError(line_no, f"expected a number or label, got '{tok}'")
    limit = 1 << bits
    if not (0 <= val < limit):
        raise AsmError(line_no, f"value {val} does not fit in {bits} bits")
    return val


def tokenize(raw_line, line_no):
    """Split a source line into (label_or_None, mnemonic_or_None, [operands])."""
    line = strip_comment(raw_line).strip()
    if not line:
        return None, None, []

    label = None
    m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", line)
    if m:
        label, rest = m.group(1), m.group(2).strip()
    else:
        rest = line

    if not rest:
        return label, None, []

    m = re.match(r"^(\S+)\s*(.*)$", rest)
    mnemonic = m.group(1).upper()
    operand_str = m.group(2).strip()

    operands = []
    if operand_str:
        # split on commas, but keep "[Rn]" memory operands as one token
        operands = [op.strip() for op in operand_str.split(",")]
    return label, mnemonic, operands


def first_pass(lines):
    """Assign an address to every instruction line and record labels."""
    labels = {}
    addr = 0
    instr_lines = []  # (line_no, mnemonic, operands, addr)
    for line_no, raw in enumerate(lines, start=1):
        label, mnemonic, operands = tokenize(raw, line_no)
        if label:
            if label in labels:
                raise AsmError(line_no, f"label '{label}' redefined")
            labels[label] = addr
        if mnemonic:
            mnemonic_u = mnemonic.upper()
            if mnemonic_u not in OPCODES and mnemonic_u not in BRANCHES and mnemonic_u not in ("MOV", "NOT"):
                raise AsmError(line_no, f"unknown mnemonic '{mnemonic}'")
            instr_lines.append((line_no, mnemonic_u, operands, addr))
            addr += 1
    return labels, instr_lines


def encode(mnemonic, operands, addr, labels, line_no):
    """Encode one instruction into a 16-bit word. Returns (word, asm_text)."""

    def field(opcode, a=0, b=0, c=0, d=0):
        # generic 4/3/3/3/3-ish packer used per-format below
        return opcode

    if mnemonic == "MOV":
        # MOV rd, rs  ==>  OR rd, rs, rs   (no dedicated move in the ISA)
        if len(operands) != 2:
            raise AsmError(line_no, "MOV expects rd, rs")
        rd = parse_reg(operands[0], line_no)
        rs = parse_reg(operands[1], line_no)
        word = (OPCODES["OR"][0] << 12) | (rd << 9) | (rs << 6) | (rs << 3)
        return word, f"OR R{rd},R{rs},R{rs}  ; MOV R{rd},R{rs}"

    if mnemonic == "NOT":
        # NOT rd, rs, rmask  ==>  XOR rd, rs, rmask   (rmask must hold 0xFF)
        if len(operands) != 3:
            raise AsmError(line_no, "NOT expects rd, rs, rmask (rmask must hold 0xFF)")
        rd = parse_reg(operands[0], line_no)
        rs = parse_reg(operands[1], line_no)
        rmask = parse_reg(operands[2], line_no)
        word = (OPCODES["XOR"][0] << 12) | (rd << 9) | (rs << 6) | (rmask << 3)
        return word, f"XOR R{rd},R{rs},R{rmask}  ; NOT R{rd},R{rs}"

    if mnemonic == "NOP":
        return 0x0000, "NOP"

    if mnemonic == "HLT":
        return (OPCODES["HLT"][0] << 12), "HLT"

    if mnemonic == "LDI":
        if len(operands) != 2:
            raise AsmError(line_no, "LDI expects rd, imm8")
        rd = parse_reg(operands[0], line_no)
        imm = parse_imm(operands[1], line_no, 8)
        word = (OPCODES["LDI"][0] << 12) | (rd << 9) | (0 << 8) | imm
        return word, f"LDI R{rd},{imm}"

    if mnemonic == "LD":
        if len(operands) != 2:
            raise AsmError(line_no, "LD expects rd, [rs1]")
        rd = parse_reg(operands[0], line_no)
        m = re.match(r"^\[\s*(\S+)\s*\]$", operands[1])
        if not m:
            raise AsmError(line_no, "LD expects the address operand in [Rn] form")
        rs1 = parse_reg(m.group(1), line_no)
        word = (OPCODES["LD"][0] << 12) | (rd << 9) | (rs1 << 6)
        return word, f"LD R{rd},[R{rs1}]"

    if mnemonic == "ST":
        if len(operands) != 2:
            raise AsmError(line_no, "ST expects [rs1], rs2")
        m = re.match(r"^\[\s*(\S+)\s*\]$", operands[0])
        if not m:
            raise AsmError(line_no, "ST expects the address operand in [Rn] form")
        rs1 = parse_reg(m.group(1), line_no)
        rs2 = parse_reg(operands[1], line_no)
        word = (OPCODES["ST"][0] << 12) | (rs2 << 9) | (rs1 << 6)
        return word, f"ST [R{rs1}],R{rs2}"

    if mnemonic in ("ADD", "SUB", "AND", "OR", "XOR"):
        if len(operands) != 3:
            raise AsmError(line_no, f"{mnemonic} expects rd, rs1, rs2")
        rd = parse_reg(operands[0], line_no)
        rs1 = parse_reg(operands[1], line_no)
        rs2 = parse_reg(operands[2], line_no)
        word = (OPCODES[mnemonic][0] << 12) | (rd << 9) | (rs1 << 6) | (rs2 << 3)
        return word, f"{mnemonic} R{rd},R{rs1},R{rs2}"

    if mnemonic in ("SHL", "SHR"):
        if len(operands) != 2:
            raise AsmError(line_no, f"{mnemonic} expects rd, rs1")
        rd = parse_reg(operands[0], line_no)
        rs1 = parse_reg(operands[1], line_no)
        word = (OPCODES[mnemonic][0] << 12) | (rd << 9) | (rs1 << 6)
        return word, f"{mnemonic} R{rd},R{rs1}"

    if mnemonic == "CMP":
        if len(operands) != 2:
            raise AsmError(line_no, "CMP expects rs1, rs2")
        rs1 = parse_reg(operands[0], line_no)
        rs2 = parse_reg(operands[1], line_no)
        word = (OPCODES["CMP"][0] << 12) | (0 << 9) | (rs1 << 6) | (rs2 << 3)
        return word, f"CMP R{rs1},R{rs2}"

    if mnemonic == "JMP":
        if len(operands) != 1:
            raise AsmError(line_no, "JMP expects addr")
        target = parse_imm(operands[0], line_no, 9, labels)
        word = (OPCODES["JMP"][0] << 12) | (0 << 9) | target
        return word, f"JMP 0x{target:03X}"

    if mnemonic in BRANCHES:
        if len(operands) != 1:
            raise AsmError(line_no, f"{mnemonic} expects addr")
        target = parse_imm(operands[0], line_no, 9, labels)
        cond = BRANCHES[mnemonic]
        word = (0xD << 12) | (cond << 9) | target
        return word, f"{mnemonic} 0x{target:03X}"

    if mnemonic == "IN":
        if len(operands) != 2:
            raise AsmError(line_no, "IN expects rd, port")
        rd = parse_reg(operands[0], line_no)
        port = parse_imm(operands[1], line_no, 8)
        word = (0xE << 12) | (rd << 9) | (0 << 8) | port
        return word, f"IN R{rd},0x{port:02X}"

    if mnemonic == "OUT":
        if len(operands) != 2:
            raise AsmError(line_no, "OUT expects port, rs")
        port = parse_imm(operands[0], line_no, 8)
        rs = parse_reg(operands[1], line_no)
        word = (0xE << 12) | (rs << 9) | (1 << 8) | port
        return word, f"OUT 0x{port:02X},R{rs}"

    raise AsmError(line_no, f"unhandled mnemonic '{mnemonic}'")


def assemble(source_text):
    lines = source_text.splitlines()
    labels, instr_lines = first_pass(lines)
    words = []
    listing = []
    for line_no, mnemonic, operands, addr in instr_lines:
        word, text = encode(mnemonic, operands, addr, labels, line_no)
        words.append(word)
        listing.append((addr, word, text))
    return words, labels, listing


def main():
    ap = argparse.ArgumentParser(description="DSD-8 assembler")
    ap.add_argument("source", help="input .asm file")
    ap.add_argument("-o", "--output", required=True, help="output .hex file ($readmemh format)")
    ap.add_argument("--listing", help="optional listing file (address, hex, decoded assembly)")
    args = ap.parse_args()

    with open(args.source) as f:
        source_text = f.read()

    try:
        words, labels, listing = assemble(source_text)
    except AsmError as e:
        print(f"{args.source}: {e}", file=sys.stderr)
        sys.exit(1)

    with open(args.output, "w") as f:
        for w in words:
            f.write(f"{w:04X}\n")

    if args.listing:
        with open(args.listing, "w") as f:
            f.write(f"; {args.source} -> {args.output}\n")
            f.write(f"; {len(words)} instructions, {len(labels)} labels\n;\n")
            for addr, word, text in listing:
                f.write(f"{addr:03X}: {word:04X}   {text}\n")
            if labels:
                f.write(";\n; labels:\n")
                for name, addr in sorted(labels.items(), key=lambda kv: kv[1]):
                    f.write(f";   {name} = 0x{addr:03X}\n")

    print(f"assembled {len(words)} instructions -> {args.output}")


if __name__ == "__main__":
    main()
