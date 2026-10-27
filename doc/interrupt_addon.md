# DSD-8 Timer/Interrupt Add-on

The interrupt add-on is isolated from the frozen baseline. It does not modify
`dsd8_cpu`, `io_bus`, or `dsd8_top`; instantiate `dsd8_interrupt_top` for a
system that includes the new peripheral.

## Files

- `rtl/interrupt_controller.v` implements ports `0x50`–`0x5F`.
- `rtl/dsd8_interrupt_top.v` combines the unchanged CPU and standard I/O bus
  with the interrupt controller.
- `tb/tb_interrupt_controller.v` checks timer, flag, source-priority, and
  masking behavior.
- `sim/interrupt_smoke.asm` and `tb/tb_dsd8_interrupt_top.v` exercise a CPU
  program polling and clearing a Timer A interrupt through the new system top.

## Register behavior

| Port | Access | Behavior |
|---|---|---|
| `0x50`–`0x51` | R/W | Timer A counter, low byte then high byte |
| `0x52`–`0x53` | W | Timer A threshold, low byte then high byte |
| `0x54`–`0x55` | R/W | Timer B counter, low byte then high byte |
| `0x56`–`0x57` | W | Timer B threshold, low byte then high byte |
| `0x58` | R | IRQ flags in bits 0–3; bit 4 is the OR of enabled pending flags |
| `0x59` | W | Write 1 to clear corresponding IRQ flag in bits 0–3 |
| `0x5A` | R/W | IRQ enables in bits 0–3; vector base in bits 7–4 |
| `0x5B` | R | Highest-priority enabled pending source (0–3) |
| `0x5C` | W | Timer A enable/mode/reset in bits 0/1/2; Timer B in 3/4/5 |
| `0x5D` | W | Write bit 0 to trigger the enabled event source |
| `0x5E` | W | Write bit 0 to trigger the enabled manual source |
| `0x5F` | W | Reserved |

Timer mode 0 counts up and sets its sticky flag when the next count equals the
threshold. Mode 1 loads the threshold on reset and counts down to zero; on
terminal count it sets the flag and disables that timer. The counter can be
read or written while stopped or running. Timer/event flags are latched only when their corresponding IRQ-enable bit is
set. If a latched source is later masked, its flag remains visible in bits 0–3
but is excluded from bit 4 and priority selection until re-enabled or cleared.
The vector-base nibble is stored and read back for software use; the CPU does
not automatically vector to a handler.
The controller does not drive a CPU interrupt pin: software polls `0x58`,
dispatches based on `0x5B`, and clears serviced flags through `0x59`.

## Verification

Run the controller unit test:

```powershell
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_interrupt_controller -o sim\tb_interrupt_controller.vvp tb\tb_interrupt_controller.v rtl\interrupt_controller.v
tools\iverilog\app\bin\vvp.exe sim\tb_interrupt_controller.vvp
```

Assemble the integration test program and run it through the interrupt-enabled
top:

```powershell
python dsd8asm.py sim\interrupt_smoke.asm -o sim\interrupt_smoke.hex
tools\iverilog\app\bin\iverilog.exe -g2012 -s tb_dsd8_interrupt_top -o sim\tb_dsd8_interrupt_top.vvp rtl\*.v tb\tb_dsd8_interrupt_top.v
tools\iverilog\app\bin\vvp.exe sim\tb_dsd8_interrupt_top.vvp
```

Run `make lint` to check the add-on together with the existing RTL, and
`python scripts/run_all.py` to verify the unchanged baseline regression.
