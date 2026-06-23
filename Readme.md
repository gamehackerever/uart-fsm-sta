# UART Controller — RTL Design, Synthesis & Static Timing Analysis

A fully functional UART (Universal Asynchronous Receiver-Transmitter) controller designed from scratch in Verilog HDL as explicit Finite State Machines (FSMs), synthesized to a gate-level netlist using Yosys targeting the open-source SkyWater Sky130 standard cell library, and analyzed for timing closure using OpenSTA.

**Tools:** Icarus Verilog · GTKWave · Yosys · OpenSTA · SkyWater Sky130 PDK  
**Language:** Verilog HDL  
**Status:** Week 1 complete (RTL + Verification) — Synthesis & STA in progress

---

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [FSM Design](#fsm-design)
- [File Structure](#file-structure)
- [Simulation & Verification](#simulation--verification)
- [Synthesis](#synthesis)
- [Static Timing Analysis](#static-timing-analysis)
- [How to Run](#how-to-run)

---

## Overview

UART is a serial communication protocol that transmits data one bit at a time over a single wire. This project implements:

- **UART TX** — takes a parallel 8-bit input and serializes it: idle → start bit (low) → 8 data bits (LSB first) → stop bit (high)
- **UART RX** — deserializes an incoming bit stream back into an 8-bit parallel output, with start-bit detection and stop-bit validation
- **UART Top** — wires TX and RX together; in loopback mode the TX output connects directly to RX input

The primary goal of this project is not just functional correctness but to demonstrate a complete **digital design flow**: RTL → functional verification → synthesis → static timing analysis → timing closure.

---

## Architecture

```
          ┌─────────────┐        tx (serial)       ┌─────────────┐
data_in ──►   UART TX   ├──────────────────────────►   UART RX   ├──► data_out
start   ──►   (FSM)     │                           │   (FSM)     │
          └──────┬──────┘                           └──────┬──────┘
                 │                                         │
              baud_clk                                  baud_clk
```

Both TX and RX are clocked by the same baud clock. In a real system, a baud rate generator module divides the system clock down to the target baud rate (e.g., 50 MHz ÷ 9600 = ~5208 clock cycles per bit period).

---

## FSM Design

### TX State Machine

```
        tx_start=1
  ┌──────────────────┐
  │                  ▼
IDLE ──────────► START ──────────► DATA ──────────► STOP
  ▲   tx=1         tx=0        tx=data[bit]    tx=1    │
  │                                bit_cnt++           │
  └────────────────────────────────────────────────────┘
                                  (bit_cnt==7 → STOP)
```

| State | Action |
|-------|--------|
| IDLE  | Hold `tx=1` (line idle high); wait for `tx_start` |
| START | Drive `tx=0` for one baud period (start bit) |
| DATA  | Shift out `data[0]` through `data[7]`, LSB first, one bit per baud clock |
| STOP  | Drive `tx=1` for one baud period (stop bit), return to IDLE |

### RX State Machine

```
        rx==0 (falling edge)
  ┌──────────────────┐
  │                  ▼
IDLE ──────────► START ──────────► DATA ──────────► STOP
  ▲   rx=1     sample bit[0]   data[bit_cnt]=rx  check rx=1  │
  │                                bit_cnt++                  │
  └───────────────────────────────────────────────────────────┘
                                  (bit_cnt==7 → STOP)
```

| State | Action |
|-------|--------|
| IDLE  | Wait for `rx` to go low (start bit detection) |
| START | Sample `data[0]`, begin reception |
| DATA  | Sample `data[1]` through `data[7]` on each baud clock posedge |
| STOP  | Validate stop bit (`rx==1`); return to IDLE |

---

## File Structure

```
uart_project/
├── uart_tx.v          # UART transmitter FSM
├── uart_rx.v          # UART receiver FSM
├── uart_top.v         # Top-level module (TX + RX + loopback)
├── uart_tx_tb.v       # TX testbench
├── uart_rx_tb.v       # RX testbench
├── uart_top_tb.v      # Loopback testbench (TX output → RX input)
├── synth.ys           # Yosys synthesis script
├── constraints.sdc    # Timing constraints for OpenSTA
├── sta_run.tcl        # OpenSTA script
└── README.md
```

---

## Simulation & Verification

### Loopback Test

The key verification test connects TX output directly to RX input and confirms that every byte transmitted is correctly received. The waveform below shows a loopback simulation:

- `data_in` — byte fed to TX
- `tx` — serial line (start bit low, 8 data bits, stop bit high)
- `data_out` — byte recovered by RX after full transmission

**Loopback waveform — `data_in = 0x88`, received `data_out = 0x88` ✓**
<img width="1787" height="231" alt="image" src="https://github.com/user-attachments/assets/3e81223a-b43e-41fd-9a35-6aa8e7a4a7cd" />
<img width="1813" height="230" alt="image" src="https://github.com/user-attachments/assets/c695c8b9-0409-4db4-bac4-a38c8bd6e766" />

Test vectors verified:

| data_in | Expected data_out | Result |
|---------|-------------------|--------|
| 0x88    | 0x88              | ✓      |
| 0xC9    | 0xC9              | ✓      |
| 0xFB    | 0xFB              | ✓      |
| 0xDF    | 0xDF              | ✓      |
| 0xED    | 0xED              | ✓      |
| 0xCA    | 0xCA              | ✓      |

### Known Design Decisions

- **Sampling point:** RX samples at the rising edge of the baud clock. In a real asynchronous system, mid-bit sampling using an oversampling clock (8x or 16x baud rate) would be used to avoid edge jitter. This is a planned improvement.
- **No parity bit:** Currently implements 8N1 format (8 data bits, no parity, 1 stop bit).

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

### Simulate TX
```bash
iverilog -o uart_tx_tb uart_tx.v uart_tx_tb.v
vvp uart_tx_tb
gtkwave uart_tx_wf.vcd
```

### Simulate RX
```bash
iverilog -o uart_rx_tb uart_rx.v uart_rx_tb.v
vvp uart_rx_tb
gtkwave uart_rx_wf.vcd
```

### Simulate Loopback (TX → RX)
```bash
iverilog -o uart_top_tb uart_tx.v uart_rx.v uart_top.v uart_top_tb.v
vvp uart_top_tb
gtkwave uart_top_wf.vcd
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
