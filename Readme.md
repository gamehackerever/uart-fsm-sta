# UART Controller — RTL Design, Synthesis & Static Timing Analysis

A fully functional UART (Universal Asynchronous Receiver-Transmitter) controller designed from scratch in Verilog HDL as explicit Finite State Machines (FSMs), synthesized to a gate-level netlist using Yosys targeting the open-source SkyWater Sky130 standard cell library, and analyzed for timing closure using OpenSTA.

**Tools:** Icarus Verilog · GTKWave · Yosys · OpenSTA · SkyWater Sky130 PDK
**Language:** Verilog HDL
**Status:** RTL + Verification complete (CDC-safe, 8x oversampled, self-checking loopback test passing) — Synthesis & STA in progress

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [FSM Design](#fsm-design)
- [File Structure](#file-structure)
- [Simulation & Verification](#simulation--verification)
- [Design Decisions & Bugs Found](#design-decisions--bugs-found)
- [Synthesis](#synthesis)
- [Static Timing Analysis](#static-timing-analysis)
- [How to Run](#how-to-run)

---

## Overview

UART is a serial communication protocol that transmits data one bit at a time over a single wire. This project implements:

- **UART TX** — takes a parallel 8-bit input and serializes it: idle → start bit (low) → 8 data bits (LSB first) → stop bit (high). Exposes a `busy` flag so a caller can't accidentally retrigger a transmission mid-byte.
- **UART RX** — deserializes an incoming, asynchronous bit stream back into an 8-bit parallel output. The `rx` line is passed through a 2-flop synchronizer before it touches any FSM logic, and each bit is sampled 8 times (oversampled) with a majority vote, making reception robust to line noise and sampling jitter. A one-cycle `data_valid` strobe marks exactly when a byte is ready.
- **Baud rate generator** — a parameterized clock divider (`CLK_FREQ`, `BAUD_RATE`) that produces both an 8x tick (drives RX oversampling) and a 1x tick derived from it (drives TX, one bit per baud period), so TX and RX stay phase-locked to the same source instead of assuming an externally supplied baud clock.
- **UART Top** — wires the baud generator, TX, and RX together into a single instantiable module.

The primary goal of this project is not just functional correctness but to demonstrate a complete **digital design flow**: RTL → functional verification → synthesis → static timing analysis → timing closure.

---

## Architecture

```
                        ┌───────────────┐
                        │   baud_gen    │
                        │ (CLK_FREQ,    │
                        │  BAUD_RATE)   │
                        └───┬───────┬───┘
                     tick_1x│       │tick_8x
                            ▼       ▼
          ┌─────────────┐        tx (serial)       ┌─────────────┐
data_in ──►   UART TX   ├──────────────────────────►   UART RX   ├──► data_out
start   ──►   (FSM)     │                           │   (FSM)     ├──► data_valid
busy    ◄───┤           │                           │             │
          └─────────────┘                           └──────┬──────┘
                                                             │
                                                        rx (async in)
                                                     2-flop synchronizer
                                                        before FSM logic
```

`uart_top.v` instantiates all three blocks above. In loopback testing, `tx` is tied directly to `rx`.

---

## FSM Design

### TX State Machine

```
        start=1 && !busy
  ┌──────────────────┐
  │                  ▼
IDLE ──────────► START ──────────► DATA ──────────► STOP
  ▲   tx=1         tx=0        tx=data[bit]    tx=1    │
  │   busy=0                      bit_cnt++   busy=0    │
  └────────────────────────────────────────────────────┘
                                  (bit_cnt==7 → STOP)
```

| State | Action |
|-------|--------|
| IDLE  | Hold `tx=1` (line idle high); latch `data` and raise `busy` on `start` (ignored if already `busy`) |
| START | Drive `tx=0` for one baud period (start bit) |
| DATA  | Shift out `data[0]` through `data[7]`, LSB first, one bit per `tick_1x` |
| STOP  | Drive `tx=1` for one baud period (stop bit), clear `busy`, return to IDLE |

### RX State Machine

```
   rx_sync==0 (after 2-flop sync)
  ┌──────────────────┐
  │                  ▼
IDLE ──────────► START ──────────► DATA ──────────► STOP
  ▲   rx=1      8x oversample +  8x oversample +   8x oversample,   │
  │             majority vote    majority vote      data_valid=1    │
  │             (verify start)   per bit, bit_cnt++                 │
  └───────────────────────────────────────────────────────────────┘
                                  (bit_cnt==7 → STOP)
```

| State | Action |
|-------|--------|
| IDLE  | Wait for the *synchronized* `rx` to go low (start bit detection) |
| START | Sample 8 times at `tick_8x`; majority-vote confirms it's a real start bit, not a glitch |
| DATA  | For each of 8 data bits: sample 8 times, majority-vote the value into `data[bit_cnt]` |
| STOP  | Sample 8 times, then pulse `data_valid` for one cycle and return to IDLE |

---

## File Structure

```
uart_project/
├── baud_gen.v          # Parameterized baud rate generator (8x + 1x ticks)
├── uart_tx.v            # UART transmitter FSM (with busy flag)
├── uart_rx.v            # UART receiver FSM (synchronizer + 8x majority vote + data_valid)
├── uart_top.v            # Top-level module: baud_gen + TX + RX wired together
├── uart_tx_tb.v          # Standalone TX testbench
├── uart_rx_tb.v          # Standalone RX testbench
├── tb_uart_loopback.v    # Self-checking top-level loopback testbench (replaces manual waveform inspection)
├── synth.ys              # Yosys synthesis script
├── constraints.sdc       # Timing constraints for OpenSTA
├── sta_run.tcl           # OpenSTA script
└── README.md
```

> `uart_top.v` and `baud_gen.v` are new additions — earlier versions of this project had only the standalone TX and RX modules with their own testbenches and no integrated top-level or baud generator.

---

## Simulation & Verification

### Loopback Test

`tb_uart_loopback.v` ties `tx` directly to `rx` and automatically checks every received byte against what was sent — no manual waveform reading required to confirm a pass. It exercises both data-pattern coverage and a control-path edge case:

| Test | Description | Result |
|------|-------------|--------|
| 0x00 | All-zero byte | ✓ |
| 0xFF | All-one byte | ✓ |
| 0xA5 | Alternating pattern (10100101) | ✓ |
| 0x5A | Alternating pattern (01011010) | ✓ |
| 0x4B | Arbitrary ASCII byte | ✓ |
| Busy contention | `start` pulsed again while a transmission is already in progress; confirms it's correctly ignored and the in-flight byte isn't corrupted | ✓ |

```
=== ALL TESTS PASSED ===
```

---

## Design Decisions & Bugs Found

- **8x oversampling with majority vote** (implemented, not just planned): `rx` is sampled 8 times per bit and the majority value is taken, so a single noisy or mistimed sample can't flip a bit. This also naturally rejects short glitches that aren't real start bits.
- **Clock domain crossing:** `rx` is asynchronous to the system clock. Sampling it directly risks metastability — if `rx` transitions right at a flop's setup/hold window, the output can resolve unpredictably. A 2-flop synchronizer sits between the raw `rx` pin and all FSM logic, giving any metastable value a full clock cycle to settle before it's used.
- **`data_valid` strobe:** added because the RX FSM previously had no way to tell a downstream consumer *when* a byte was actually ready — `data` would just change value with no signal to sample it on.
- **`busy` flag on TX:** added so a caller can't retrigger a new transmission mid-byte by holding or re-pulsing `start`; verified explicitly in the loopback testbench.
- **Bug found via simulation — vote register width:** the majority-vote accumulator (`vote`) was originally 3 bits wide (max value 7). When a bit is a clean, consistent `1` across all 8 oversamples, `vote + rx_sync` reaches **8**, which needs 4 bits. Because the comparison was against a 3-bit constant, the sum was computed at 3-bit width and silently truncated (8 → 0), misreading a solid `1` bit as `0`. This didn't show up in code review — it only appeared once the self-checking loopback testbench was run against real data patterns. Fixed by widening `vote` to 4 bits. This is the reason the testbench asserts against expected values automatically rather than relying on eyeballing a waveform.
- **8N1 format:** 8 data bits, no parity, 1 stop bit.

---

## Synthesis

*(To be completed — Week 2)*

Synthesis target: **SkyWater Sky130 HD standard cell library** (`sky130_fd_sc_hd__tt_025C_1v80.lib`)
Tool: **Yosys 0.66**

```bash
yosys synth.ys
```

Results will include:
- Cell count after synthesis
- Gate-level netlist (`uart_top_synth.v`)
- Any latch warnings (should be zero)

---

## Static Timing Analysis

*(To be completed — Week 3)*

Tool: **OpenSTA**
Target clock: TBD MHz (will be determined by synthesis results)

Analysis will include:
- Critical path report
- Setup and hold slack at target frequency
- Maximum operating frequency before timing violations
- Before/after comparison after timing closure fix

---

## How to Run

### Prerequisites
Install [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases) which includes Icarus Verilog, GTKWave, Yosys, and OpenSTA.

```bash
# Linux/WSL
source oss-cad-suite/environment

# Windows PowerShell
. "D:\oss-cad-suite\environment.ps1"
```

### Simulate TX (standalone)
```bash
iverilog -o uart_tx_tb uart_tx.v uart_tx_tb.v
vvp uart_tx_tb
gtkwave uart_tx_wf.vcd
```

### Simulate RX (standalone)
```bash
iverilog -o uart_rx_tb uart_rx.v uart_rx_tb.v
vvp uart_rx_tb
gtkwave uart_rx_wf.vcd
```

### Simulate full loopback (baud_gen + TX + RX, self-checking)
```bash
iverilog -o sim.out baud_gen.v uart_rx.v uart_tx.v uart_top.v tb_uart_loopback.v
vvp sim.out
gtkwave uart_loopback.vcd
```

### Synthesize
```bash
yosys synth.ys
```

### Run STA
```bash
sta sta_run.tcl
```

---

## Author

**Srinand E K**
B.Tech, Electronics & Communication Engineering
National Institute of Technology, Calicut (2023–2027)
[github.com/gamehackerever](https://github.com/gamehackerever)