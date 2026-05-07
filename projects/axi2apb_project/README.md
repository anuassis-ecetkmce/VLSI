# AXI2APB Bridge Verification Using UVM

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Project Objectives](#2-project-objectives)
3. [Design Architecture](#3-design-architecture)
   - [Bridge Overview](#31-bridge-overview)
   - [RTL Module Hierarchy](#32-rtl-module-hierarchy)
   - [APB Arbiter](#33-apb-arbiter)
   - [Address Map](#34-address-map)
4. [RTL Design — Module Descriptions](#4-rtl-design--module-descriptions)
5. [Verification Methodology](#5-verification-methodology)
   - [UVM Layered Architecture](#51-uvm-layered-architecture)
   - [UVM Class Hierarchy](#52-uvm-class-hierarchy)
6. [File and Folder Structure](#6-file-and-folder-structure)
7. [UVM Components — Detailed Description](#7-uvm-components--detailed-description)
   - [AXI VIP](#71-axi-vip)
   - [APB VIP](#72-apb-vip)
   - [Environment](#73-environment)
   - [Tests and Sequences](#74-tests-and-sequences)
   - [Packages](#75-packages)
8. [Interfaces](#8-interfaces)
9. [Testbench Top](#9-testbench-top)
10. [Test Cases](#10-test-cases)
    - [Standalone RTL Testbench (tb_bridge.sv)](#101-standalone-rtl-testbench-tb_bridgesv)
    - [UVM Test Suite](#102-uvm-test-suite)
11. [Scoreboard & Coverage](#11-scoreboard--coverage)
12. [Simulation Flow](#12-simulation-flow)
    - [Makefile Targets](#121-makefile-targets)
    - [Running a Specific Test](#122-running-a-specific-test)
13. [Waveform and Debug](#13-waveform-and-debug)
14. [Known Limitations](#14-known-limitations)
15. [Future Enhancements](#15-future-enhancements)

---

## 1. Introduction

Modern SoC designs integrate multiple IP blocks that communicate using different bus protocols. **AXI (Advanced eXtensible Interface)** is the standard for high-performance, high-bandwidth master–slave interconnects, while **APB (Advanced Peripheral Bus)** serves low-power, low-frequency peripheral access.

An **AXI-to-APB bridge** is the translation layer between these two worlds. It accepts burst-capable AXI4 transactions from a high-speed master, serializes them into single-beat APB transactions, and returns the APB slave response back to the AXI master — all while preserving protocol correctness, data integrity, ordering, and error signaling.

Any mismatch in address mapping, data values, write/read direction, timing, or error codes at this boundary can cause silent data corruption or system failures. This project builds a **comprehensive, reusable UVM-based verification environment** to validate the functional correctness of the AXI-to-APB bridge RTL.

---

## 2. Project Objectives

- Design a **reusable, layered UVM verification environment** for the AXI2APB bridge.
- Generate a wide variety of AXI transactions (writes, reads, burst, single-beat, slow/fast, error conditions) and verify their correct translation into APB protocol traffic.
- Monitor both the AXI and APB interfaces independently and cross-check via a **scoreboard**.
- Verify the following properties end-to-end:
  - **Address mapping** — AXI address correctly propagated to APB `PADDR`.
  - **Data integrity** — Write data and read data preserved without corruption.
  - **Direction correctness** — AXI write → APB `PWRITE=1`; AXI read → APB `PWRITE=0`.
  - **Response handling** — `OKAY`, `SLVERR`, and `DECERR` correctly returned on the AXI B and R channels.
  - **Backpressure** — Engine stalls gracefully when response FIFOs are full.
  - **Arbitration fairness** — Write-priority arbiter does not starve reads beyond `MAX_WR_CONSEC` consecutive writes.
  - **Error recovery** — Bridge returns to `IDLE` correctly after `DECERR` and `SLVERR` conditions.

---

## 3. Design Architecture

### 3.1 Bridge Overview

The bridge is a **unified, single-engine** design that handles both AXI write and read channels, sharing a single APB master port.

```
AXI Master
    │
    ├─── AW + W channels ──► axi_input_stage      ──► FIFO (cmd + data)
    │                                                         │
    │                                              ┌──────────▼──────────┐
    │                                              │   apb_arbiter        │
    │                                              │ (wr-priority +       │
    │                                              │  starvation guard)   │
    │                                              └──────────┬──────────┘
    │                                                         │
    ├─── AR channel ────────► axi_read_input_stage ──► FIFO  │
    │                                                         │
    │                                              ┌──────────▼──────────┐
    │                                              │ unified_transaction  │
    │                                              │ _engine (FSM)        │
    │                                              │                      │
    │                                              │  IDLE→SETUP→DECODE   │
    │                                              │  →ENABLE→ACCESS      │
    │                                              │  →[WAIT/RESP_STALL   │
    │                                              │   /ERROR]→IDLE       │
    │                                              └────┬────────┬────────┘
    │                                                   │        │
    ├─── B channel ◄─────────── axi_response_stage ◄───┘        │
    │                            (write resp FIFO)               │
    │                                                            │
    └─── R channel ◄─────────── axi_read_data_stage ◄───────────┘
                                 (rdata FIFO)
                                        │
                                        ▼
                                 APB Slave Bus
```

### 3.2 RTL Module Hierarchy

```
axi_apb_bridge_top
├── axi_input_stage          (AXI Write: AW + W → FIFO)
│   ├── axi_hold_reg         (AW hold register)
│   ├── sync_fifo            (AW command FIFO)
│   ├── axi_hold_reg         (W data hold register)
│   └── sync_fifo            (W data FIFO)
│
├── axi_read_input_stage     (AXI Read: AR → FIFO)
│   ├── axi_hold_reg         (AR hold register)
│   └── sync_fifo            (AR command FIFO)
│
├── apb_arbiter              (Write-priority + starvation guard)
│
├── unified_transaction_engine  (APB FSM + address decode + response ctrl)
│   ├── address_decoder         (Combinational slave select)
│   ├── unified_apb_output_regs (Registered APB outputs: PSEL, PENABLE, PADDR, PWDATA, PSTRB, PWRITE)
│   ├── write_response_ctrl     (Latch BRESP + BID; pulse txn_complete)
│   └── read_response_ctrl      (Latch RRESP + RID + RDATA; pulse txn_complete)
│
├── axi_response_stage       (Write response: FIFO → AXI B channel)
│   └── sync_fifo
│
└── axi_read_data_stage      (Read data: FIFO → AXI R channel)
    └── sync_fifo
```

### 3.3 APB Arbiter

The arbiter implements **write-priority with starvation protection**:

| Condition | Decision |
|-----------|----------|
| Only write pending | Grant write |
| Only read pending | Grant read |
| Both pending, `wr_consec_cnt < MAX_WR_CONSEC` | Grant write |
| Both pending, `wr_consec_cnt >= MAX_WR_CONSEC` | Force grant read (anti-starvation) |

After a read grant, `wr_consec_cnt` resets to 0. Default `MAX_WR_CONSEC = 4`.

### 3.4 Address Map

Default slave address map (parameterizable):

| Slave | Base Address | Size |
|-------|-------------|------|
| Slave 0 | `0x1000_0000` | 256 MB |
| Slave 1 | `0x2000_0000` | 256 MB |
| Slave 2 | `0x3000_0000` | 256 MB |
| Slave 3 | `0x4000_0000` | 256 MB |

Addresses outside all slave ranges generate a **DECERR** response on the AXI side with no APB activity.

---

## 4. RTL Design — Module Descriptions

### `sync_fifo`
Generic synchronous FIFO using a dual-pointer (extra-bit) architecture. Used for command, data, write response, and read data buffering throughout the bridge.

- **Parameters:** `WIDTH`, `DEPTH`
- **Full/empty detection:** Extra MSB of pointer used; no gray code needed (single clock domain)

### `axi_hold_reg`
Single-entry hold register that absorbs an AXI handshake beat and presents it to the downstream FIFO. Implements three priority cases: drain-only, capture-only, and back-to-back (simultaneous drain + capture). Clears stale data on drain to prevent accidental re-reads.

### `address_decoder`
Combinational decoder that checks the transaction address against all `NUM_SLAVES` base/size pairs. Asserts `slave_sel[i]` for the matching slave and deasserts `decode_error`. If no slave matches, `decode_error = 1` and `slave_sel = 0`.

### `write_response_ctrl` / `read_response_ctrl`
Latches the response ID, status (`OKAY`/`SLVERR`/`DECERR`), and (for reads) `PRDATA` one cycle after `resp_valid` fires. Pulses `txn_complete` for exactly one cycle to write the response FIFO. The one-cycle delay avoids a race between the `resp_valid` edge and the next `txn_start` overwriting `txn_id_reg`.

### `unified_apb_output_regs`
Registered APB output stage. Driven by three control signals:
- `load_en` (ENABLE state) — captures address, data, strobe, direction; deasserts PENABLE
- `enable_set` (ACCESS/WAIT state) — asserts PENABLE
- `clear_en` (IDLE state) — deasserts PSEL and PENABLE

### `apb_arbiter`
Write-priority arbiter with a saturating consecutive-write counter and configurable starvation threshold (`MAX_WR_CONSEC`). Grant outputs are registered to avoid glitches at the engine's `txn_start` decode.

### `unified_transaction_engine`
8-state APB FSM that handles both write and read transactions. The `txn_is_write` flag stored at `txn_start` determines which response controller receives `resp_valid`.

**FSM State Encoding:**

| State | Encoding | Description |
|-------|----------|-------------|
| `IDLE` | `0000` | Waiting for arbitrated grant + valid command |
| `SETUP` | `0001` | Capture registers written; decoder sees old address |
| `DECODE` | `0010` | Decoder settled; branch on `decode_error` |
| `ENABLE` | `0011` | APB SETUP phase: `PSEL=1`, `PENABLE=0` |
| `ACCESS` | `0100` | APB ACCESS phase: `PSEL=1`, `PENABLE=1`, wait for `PREADY` |
| `WAIT` | `0101` | `PREADY` not asserted in ACCESS; wait here |
| `RESP_STALL` | `0110` | `PREADY` seen but response FIFO full; hold APB outputs |
| `ERROR` | `0111` | Decode error; generate `DECERR`, no APB activity |

### `axi_input_stage`
Combines two `axi_hold_reg + sync_fifo` pairs to independently buffer the AW (address+ID+length) and W (data+strobe+last) channels. Decouples AXI handshake timing from the APB engine's consumption rate.

### `axi_read_input_stage`
Single `axi_hold_reg + sync_fifo` pair for the AR channel. No data channel is needed for reads.

### `axi_response_stage`
Write response stage: packs `{BRESP, BID}` into a FIFO on `txn_complete`. Exports `bvalid`/`bresp`/`bid` to the AXI B channel. The `resp_fifo_full` signal feeds back to the engine for backpressure.

### `axi_read_data_stage`
Read data stage: packs `{RRESP, RID, RDATA}` into a FIFO on `txn_complete`. Exports `rvalid`/`rdata`/`rresp`/`rid`/`rlast` to the AXI R channel. `rlast` is hardwired to `1'b1` (single-beat only). `rdata_fifo_full` feeds back to the engine for backpressure.

### `axi_apb_bridge_top`
Integration wrapper. Instantiates all sub-modules and wires internal signals. Exposes the full AXI4 master interface and APB master interface.

---

## 5. Verification Methodology

### 5.1 UVM Layered Architecture

The environment follows the standard UVM layered architecture:

```
┌──────────────────────────────────────────────────────────────┐
│                        Test Layer                            │
│         cfs_bridge_test_reg_access (extends test_base)       │
└───────────────────────────┬──────────────────────────────────┘
                            │
┌───────────────────────────▼──────────────────────────────────┐
│                     Environment Layer                        │
│                      cfs_bridge_env                          │
│                                                              │
│   ┌──────────────────┐        ┌────────────────────────┐     │
│   │   AXI Agent      │        │      APB Agent          │    │
│   │  (UVM_ACTIVE)    │        │     (UVM_ACTIVE)        │    │
│   │                  │        │                         │    │
│   │  ┌────────────┐  │        │  ┌───────────────────┐  │    │
│   │  │ Sequencer  │  │        │  │    Sequencer       │  │    │
│   │  ├────────────┤  │        │  ├───────────────────┤  │    │
│   │  │   Driver   │  │        │  │      Driver        │  │    │
│   │  ├────────────┤  │        │  ├───────────────────┤  │    │
│   │  │  Monitor   │──┼──┐  ┌──┼──│      Monitor       │  │    │
│   │  └────────────┘  │  │  │  │  └───────────────────┘  │    │
│   └──────────────────┘  │  │  └────────────────────────┘     │
│                          │  │                                 │
│   ┌──────────────────────▼──▼──────────────────────────┐     │
│   │               axi2apb_scoreboard                    │     │
│   │         (AXI ↔ APB transaction comparison)          │     │
│   └─────────────────────────────────────────────────────┘     │
│                                                              │
│   ┌──────────────────────────────────────────────────────┐   │
│   │          cfs_bridge_virtual_sequencer                 │   │
│   └──────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

### 5.2 UVM Class Hierarchy

#### AXI Side

```
uvm_sequence_item
  └── axi_transaction           (base transaction with data array, delays)
        ├── axi_item_drv        (driver-side item; inherits axi_transaction)
        └── axi_item_mon        (monitor-side item; adds timestamp, accepted flag)

uvm_sequencer #(axi_transaction)
  └── axi_sequencer

uvm_driver #(axi_transaction)
  └── axi_driver                (drives AW, W, AR channels; collects B, R)

uvm_component
  └── axi_monitor               (samples AW/W/B for writes, AR/R for reads)

uvm_component
  └── axi_agent_config          (VIF accessor, active/passive, coverage enable)

uvm_agent
  └── axi_agent                 (builds driver, sequencer, monitor, coverage)

uvm_subscriber #(axi_transaction)
  └── axi_coverage_subscriber   (functional coverage: direction, len, size, cross)

uvm_sequence #(axi_transaction)
  └── axi_sequence_base
        ├── axi_write_stress_seq        (20 back-to-back writes, no delays)
        ├── axi_write_slow_master_seq   (8 writes with high inter-beat delays)
        └── axi_write_random_delay_seq  (20 writes with randomized delays)

uvm_sequence #(axi_transaction)
  └── axi_sequence_rw           (interleaved write + read pairs, configurable count)

uvm_sequence #(axi_transaction)
  └── axi_random_read_seq       (20 random single-beat reads)
```

#### APB Side

```
uvm_sequence_item
  └── cfs_apb_trans             (base APB transaction: addr, dir, wdata, rdata, response)
        ├── cfs_apb_item_drv    (adds pre/post drive delay constraints)
        └── cfs_apb_item_mon    (adds response, length, prev_item_delay)

uvm_sequencer #(cfs_apb_item_drv)
  └── cfs_apb_sequencer

uvm_driver #(cfs_apb_item_drv)
  └── cfs_apb_driver            (APB slave BFM: responds to PSEL+PENABLE, stores memory)

uvm_monitor
  └── cfs_apb_monitor           (captures APB transactions at PREADY assertion)

uvm_component
  └── cfs_apb_agent_config      (VIF, active/passive, delay/error config)

uvm_agent
  └── cfs_apb_agent             (builds driver, sequencer, monitor)

uvm_sequence #(cfs_apb_item_drv)
  └── cfs_apb_sequence_base
```

#### Environment and Test

```
uvm_scoreboard
  └── axi2apb_scoreboard        (compares AXI and APB transaction queues)

uvm_sequencer
  └── cfs_bridge_virtual_sequencer  (holds handles to axi_sqr and apb_sqr)

uvm_env
  └── cfs_bridge_env            (integrates agents, scoreboard, virtual sequencer)

uvm_sequence
  └── cfs_bridge_virtual_sequence   (top-level vseq; orchestrates sub-sequences)
        └── cfs_bridge_address_align_vseq    (address alignment stress)
        └── cfs_bridge_burst_variation_vseq  (burst length and data width stress)
        └── cfs_bridge_narrow_full_band_vseq (narrow vs full bandwidth)

uvm_test
  └── cfs_bridge_test_base
        └── cfs_bridge_test_reg_access  (default test; starts virtual sequence)
```

---

## 6. File and Folder Structure

```
axi2apb_project/
│
├── README.md                               ← This document
├── Makefile                                ← Build and simulation flow
├── .gitignore                              ← Excludes sim artifacts
│
├── design/                                 ← RTL source files
│   ├── design.sv                           ← Single-file flat integration (EDA Playground)
│   ├── integrated_bridge.sv                ← Full integrated bridge (alternative flat file)
│   ├── tb_bridge.sv                        ← Standalone RTL testbench (no UVM)
│   │
│   ├── common/
│   │   ├── sync_fifo.sv                    ← Generic synchronous FIFO
│   │   └── axi_hold_reg.sv                 ← AXI handshake hold register
│   │
│   ├── axi_interface/
│   │   └── axi_read_input_stage.sv         ← AR channel FIFO (standalone module)
│   │
│   ├── apb_interface/
│   │   └── read_transaction_engine.sv      ← APB FSM for read-only bridge
│   │
│   ├── response/
│   │   └── axi_read_data_stage.sv          ← R channel FIFO (standalone module)
│   │
│   └── top/
│       └── axi_apb_read_bridge_top.sv      ← Read-only bridge top (standalone)
│
├── testbench/
│   └── axi_apb_bridge_tb_top.sv            ← UVM testbench top module
│
└── uvm/
    │
    ├── axi_vip/                            ← AXI Verification IP
    │   ├── axi_if.sv                       ← AXI4 interface with clocking block
    │   ├── axi_types.sv                    ← AXI type definitions package
    │   ├── axi_transaction.sv              ← Base AXI sequence item (data array, delays)
    │   ├── axi_item_base.sv                ← Protocol-agnostic AXI item base
    │   ├── axi_item_drv.sv                 ← Driver-side sequence item
    │   ├── axi_item_mon.sv                 ← Monitor-side sequence item
    │   ├── axi_agent_config.sv             ← VIF, active/passive, parameters
    │   ├── axi_sequencer.sv                ← AXI sequencer
    │   ├── axi_driver.sv                   ← Drives AW/W/AR; reads B/R channels
    │   ├── axi_monitor.sv                  ← Monitors AW/W/AR/B/R channels
    │   ├── axi_bridge_coverage.sv          ← Functional coverage model
    │   ├── axi_agent.sv                    ← AXI agent (assembles VIP)
    │   └── axi_sequence_base.sv            ← Base sequence class
    │
    ├── apb_vip/                            ← APB Verification IP
    │   ├── cfs_apb_if.sv                   ← APB interface definition
    │   ├── cfs_apb_types.sv                ← APB typedef, enum declarations
    │   ├── cfs_apb_trans.sv                ← Base APB transaction
    │   ├── cfs_apb_item_drv.sv             ← Driver-side APB item (delays)
    │   ├── cfs_apb_item_mon.sv             ← Monitor-side APB item
    │   ├── cfs_apb_agent_config.sv         ← VIF, delay/error injection config
    │   ├── cfs_apb_sequencer.sv            ← APB sequencer
    │   ├── cfs_apb_driver.sv               ← APB slave BFM (memory model)
    │   ├── cfs_apb_monitor.sv              ← Captures APB transactions
    │   ├── cfs_apb_agent.sv                ← APB agent (assembles VIP)
    │   └── cfs_apb_sequence_base.sv        ← Base APB sequence
    │
    ├── env/                                ← Environment and checking components
    │   ├── cfs_bridge_env.sv               ← Top environment; instantiates agents & SCB
    │   ├── cfs_bridge_virtual_sequencer.sv ← Virtual sequencer (holds sqr handles)
    │   └── scoreboard.sv                   ← AXI ↔ APB transaction comparator
    │
    ├── tests/                              ← Test cases and sequences
    │   ├── cfs_bridge_test_base.sv         ← Base test class (creates env)
    │   ├── cfs_bridge_test_reg_access.sv   ← Default UVM test
    │   ├── cfs_bridge_virtual_sequence.sv  ← Master virtual sequence (orchestrates all)
    │   ├── axi_sequence_rw.sv              ← Interleaved write+read pairs
    │   ├── axi_write_sequence.sv           ← Stress / slow / random write sequences
    │   ├── axi_random_read_seq.sv          ← Random read sequence (20 transactions)
    │   ├── adress_alignment_test.sv        ← Address alignment stress test
    │   ├── datawidth_diffburstsize.sv      ← Burst length and data width stress
    │   └── narrow_fullbandwidth.sv         ← Narrow vs full bandwidth test
    │
    └── packages/                           ← Package wrapper files
        ├── cfs_apb_pkg.sv                  ← Wraps all APB VIP files into a package
        ├── axi_pkg.sv                      ← Wraps all AXI VIP files into a package
        ├── cfs_bridge_pkg.sv               ← Wraps env files; imports APB+AXI packages
        └── cfs_bridge_test_pkg.sv          ← Wraps test files; imports bridge package
```

---

## 7. UVM Components — Detailed Description

### 7.1 AXI VIP

#### `axi_if.sv`
SystemVerilog interface for AXI4. Contains all five AXI channels (AW, W, B, AR, R), a clocking block `cb` for race-free driving and sampling, a `master` modport, and a `reset_signals()` task.

Key signals:
- Write: `AWID`, `AWADDR`, `AWLEN`, `AWSIZE`, `AWBURST`, `AWVALID/READY`, `WDATA`, `WSTRB`, `WLAST`, `WVALID/READY`, `BVALID/READY`, `BRESP`, `BID`
- Read: `ARID`, `ARADDR`, `ARLEN`, `ARSIZE`, `ARBURST`, `ARVALID/READY`, `RDATA`, `RRESP`, `RLAST`, `RID`, `RVALID/READY`

#### `axi_transaction.sv`
Core sequence item used throughout the AXI VIP. Fields include:
- `id`, `addr`, `len`, `size`, `burst` — AXI control fields
- `is_write` — direction flag
- `data_ary[]` — dynamic array holding write/read data (size = `len + 1`)
- `resp` — captured response code
- `pre_addr_delay`, `addr_to_data_gap`, `inter_beat_delay`, `wait_for_bresp_delay` — timing knobs
- Constraints: address alignment (`addr % (1<<size) == 0`), data array sizing, default soft delay distributions

#### `axi_driver.sv`
Drives write transactions by sequentially handling AW, W, and B channels with configurable inter-beat delays. Drives read transactions on the AR channel then samples the R channel. Uses the clocking block `axi_vif.cb` for all signal assignments.

#### `axi_monitor.sv`
Passive monitor. In `run_phase`, waits for AW+AWREADY or AR+ARREADY handshakes, then captures all associated data beats and the final response. Writes completed `axi_transaction` objects to the `axi_ap` analysis port for the scoreboard and coverage.

#### `axi_coverage_subscriber.sv`
Implements a UVM subscriber connected to the AXI monitor's analysis port. The `axi_cg` covergroup tracks:
- `cp_direction` — read vs write
- `cp_len` — single-beat, short burst (1–7), long burst (8–15)
- `cp_size` — 1B, 2B, 4B transfer sizes
- `cross_dir_size` — cross coverage of direction × size

#### `axi_agent_config.sv`
Configuration object. Stores the virtual interface handle (private, with accessor functions), active/passive mode, coverage enable flag, and AXI parameters (`id_width`, `addr_width`, `data_width`).

### 7.2 APB VIP

#### `cfs_apb_if.sv`
APB interface. Signals: `presetn`, `psel[3:0]`, `penable`, `pwrite`, `pstrb[3:0]`, `pready`, `pslverr`, `paddr`, `pwdata`, `prdata`, `pprot`. Clock input `pclk`.

#### `cfs_apb_driver.sv`
Implements an **APB slave Bus Functional Model (BFM)**. Key behaviors:
- Waits for the APB SETUP phase (`PSEL!=0 && PENABLE=0`)
- Tries to get a response configuration item from the sequencer; creates a default if none is available
- Applies configurable wait states before asserting `PREADY`
- On writes: stores `PWDATA` into an associative memory array
- On reads: returns data from the memory array (or a random value if address not initialized)
- Supports error injection via `enable_error_injection` and `error_injection_percentage`
- Implements a timeout watchdog

#### `cfs_apb_monitor.sv`
Monitors APB transactions. Detects SETUP phase, samples address and direction, then waits for ENABLE + PREADY. Captures `PSLVERR` and `PRDATA` (for reads). Writes `cfs_apb_item_mon` to the `output_port` analysis port.

#### `cfs_apb_agent_config.sv`
APB-specific configuration. Fields include:
- `enable_response_delay`, `enable_random_delay` — control wait state injection
- `min/max_response_delay` — wait state range (0–10 cycles default)
- `enable_wait_states`, `min/max_wait_states` — APB wait state parameters
- `enable_error_injection`, `error_injection_percentage` — SLVERR injection control

### 7.3 Environment

#### `cfs_bridge_env.sv`
The top-level UVM environment. Instantiates:
- `cfs_apb_agent` — APB slave agent
- `axi_agent` — AXI master agent
- `axi2apb_scoreboard` — comparison engine
- `cfs_bridge_virtual_sequencer` — virtual sequencer

In `connect_phase`, connects both monitor analysis ports to the scoreboard exports and sets the virtual sequencer's agent handles.

#### `cfs_bridge_virtual_sequencer.sv`
Holds handles to `axi_sqr` (axi_sequencer) and `apb_sqr` (cfs_apb_sequencer). Allows virtual sequences to start sub-sequences on both agents without coupling the sequences to specific agent instances.

#### `scoreboard.sv` (`axi2apb_scoreboard`)
The scoreboard uses two separate `uvm_analysis_imp` ports (via the `_axi` and `_apb` suffixes). It maintains two queues (`axi_queue`, `apb_queue`) and in `check_data()` pops one AXI transaction and `len+1` APB transactions to compare:

1. **Direction** — `axi_tr.is_write` must match `apb_tr.dir`
2. **Address** — Expected APB address = `axi_addr + i * 4` (INCR burst, 4-byte aligned)
3. **Write data** — `apb_tr.wdata` must equal `axi_tr.data_ary[i]`
4. **Read data** — `apb_tr.rdata` must equal `axi_tr.data_ary[i]`

Reports totals in `report_phase` and warns of dangling transactions.

### 7.4 Tests and Sequences

#### `cfs_bridge_test_base.sv`
Base test class. Builds the `cfs_bridge_env` in `build_phase`. All tests extend this class.

#### `cfs_bridge_test_reg_access.sv`
Default test. In `run_phase`:
1. Raises the test objection
2. Creates and starts a `cfs_bridge_virtual_sequence` on the environment's virtual sequencer
3. Drops the objection on completion

#### `cfs_bridge_virtual_sequence.sv`
The master virtual sequence. Runs the following sub-sequences with time gaps between them, controlled by enable flags (`rw_seq`, `wr_stress_seq`, `wr_slow_seq`, `wr_rand_seq`):

| Sub-sequence | Purpose |
|---|---|
| `axi_sequence_rw` (6 transactions) | Write+read round-trip pairs |
| `axi_write_stress_seq` | 20 back-to-back writes, no delays |
| `axi_write_slow_master_seq` | 8 writes with 10–30 cycle delays |
| `axi_write_random_delay_seq` | 20 writes with random delays |

#### `axi_sequence_rw.sv`
Randomizable sequence. For each of `num_trans` iterations, sends one write then one read to the same address. Default: `num_trans` randomized in [1:10]; `addr_stride = 4`.

#### `axi_write_sequence.sv`
Three sequences for write stress testing:
- **`axi_write_stress_seq`** — 20 writes with all delays = 0
- **`axi_write_slow_master_seq`** — 8 writes with `pre_addr_delay`∈[10:20], `addr_to_data_gap`∈[15:30], `inter_beat_delay`∈[5:10], `wait_for_bresp_delay`∈[10:25]
- **`axi_write_random_delay_seq`** — 20 writes with fully randomized delays

#### `axi_random_read_seq.sv`
20 random single-beat reads. Address constrained to [0x1000_0000 : 0x4FFF_FFFF]. `pre_addr_delay`∈[5:25].

#### `adress_alignment_test.sv` (`cfs_bridge_address_align_vseq`)
Extends `cfs_bridge_virtual_sequence`. Runs 50 transactions with:
- All address bit-patterns for `addr[1:0]` (0, 1, 2, 3)
- Sizes: 1B, 2B, 4B
- Short bursts (len ∈ [0:3])

#### `datawidth_diffburstsize.sv` (`cfs_bridge_burst_variation_vseq`)
Extends `cfs_bridge_virtual_sequence`. Runs 30 transactions with:
- Sizes: 1B, 2B, 4B
- Burst lengths: full range [0:15] (up to 16 beats)
- Random data values across full range

#### `narrow_fullbandwidth.sv` (`cfs_bridge_narrow_full_band_vseq`)
Extends `cfs_bridge_virtual_sequence`. Runs 50 transactions with:
- Mixed sizes (1B, 2B, 4B)
- Random strobes [0x1 : 0xF]
- Word-aligned addresses

### 7.5 Packages

| Package File | Contents |
|---|---|
| `cfs_apb_pkg.sv` | All APB VIP files |
| `axi_pkg.sv` | `axi_types_pkg` + all AXI VIP files |
| `cfs_bridge_pkg.sv` | Imports APB+AXI packages; includes env files |
| `cfs_bridge_test_pkg.sv` | Imports bridge package; includes test and sequence files |

**Compilation order (enforced by Makefile):**

```
cfs_apb_pkg.sv → cfs_bridge_pkg.sv → cfs_bridge_test_pkg.sv
```

---

## 8. Interfaces

### AXI Interface (`axi_if.sv`)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `ACLK` | input | 1 | AXI clock |
| `ARESETn` | input | 1 | Active-low reset |
| `AWID..AWVALID` | master→DUT | — | Write address channel |
| `AWREADY` | DUT→master | 1 | Write address ready |
| `WDATA..WVALID` | master→DUT | — | Write data channel |
| `WREADY` | DUT→master | 1 | Write data ready |
| `BVALID, BRESP, BID` | DUT→master | — | Write response channel |
| `BREADY` | master→DUT | 1 | Write response ready |
| `ARID..ARVALID` | master→DUT | — | Read address channel |
| `ARREADY` | DUT→master | 1 | Read address ready |
| `RVALID, RDATA, RRESP, RLAST, RID` | DUT→master | — | Read data channel |
| `RREADY` | master→DUT | 1 | Read data ready |

### APB Interface (`cfs_apb_if.sv`)

| Signal | Direction | Width | Description |
|--------|-----------|-------|-------------|
| `pclk` | input | 1 | APB clock |
| `presetn` | — | 1 | Active-low reset |
| `psel[3:0]` | DUT→slave | 4 | Slave select (one-hot) |
| `penable` | DUT→slave | 1 | Access phase enable |
| `pwrite` | DUT→slave | 1 | `1`=write, `0`=read |
| `paddr` | DUT→slave | 32 | Transfer address |
| `pwdata` | DUT→slave | 32 | Write data |
| `pstrb[3:0]` | DUT→slave | 4 | Write byte strobes |
| `pready` | slave→DUT | 1 | Transfer complete |
| `prdata` | slave→DUT | 32 | Read data |
| `pslverr` | slave→DUT | 1 | Slave error flag |
| `pprot[2:0]` | DUT→slave | 3 | Protection attributes |

---

## 9. Testbench Top

`testbench/axi_apb_bridge_tb_top.sv` is the UVM testbench root module. It:

1. **Instantiates interfaces** — `axi_if` (tied to `axi_aclk`/`axi_aresetn`) and `cfs_apb_if` (shares the AXI clock; `presetn` driven from `axi_aresetn`)
2. **Instantiates the DUT** — `axi_apb_bridge_top` with 32-bit address/data, 4-bit ID, 4 slaves
3. **Generates a 100 MHz clock** — 10 ns period on `axi_aclk`
4. **Applies reset** — 20-cycle active-low reset then deassert
5. **Registers virtual interfaces** in `uvm_config_db` for the AXI and APB agents
6. **Calls `run_test("")`** — test name resolved via `+UVM_TESTNAME` plusarg
7. **Sets a 100 ms safety timeout** — `uvm_fatal` if simulation exceeds this limit

---

## 10. Test Cases

### 10.1 Standalone RTL Testbench (`tb_bridge.sv`)

The standalone testbench (`module tb_integrated_bridge`) provides 12 directed test scenarios that run without UVM. It includes an embedded APB slave model with configurable wait states and error injection.

| Test | ID | Description | Checks |
|------|----|-------------|--------|
| **T1** | Write + Read round-trip | Write `0xA001_0001` to `0x1000_0000`, then read back | `BRESP=OKAY, BID=1`; `RDATA=0xA001_0001, RRESP=OKAY, RID=2` |
| **T2** | Read-After-Write ordering | Write to `0x2000_0000`, issue read to same address one cycle later | Correct data returned in RAW order |
| **T3** | Simultaneous Write + Read | Write and read to different addresses at the same time | Both responses correct and independent |
| **T4** | Starvation protection | 5 consecutive writes + 1 pending read | Read granted after `MAX_WR_CONSEC=4` consecutive writes |
| **T5** | Interleaved W-R-W-R, slow PREADY | 4 transactions with `pready_delay=1` | All responses correct under wait states |
| **T6** | Decode error | Read from `0xFFFF_0000` (unmapped) | `RRESP=2'b11` (DECERR), `RDATA=0` |
| **T7** | Slave error | Write with `inject_pslverr=1` | `BRESP=2'b10` (SLVERR) |
| **T8** | Back-to-back reads | 4 reads to all 4 slaves | Each returns correct preloaded data |
| **T9** | Back-to-back writes + memory verify | 4 writes to all 4 slaves | `smem` array checked after all responses |
| **T10** | Simultaneous W+R, slow PREADY | Write + read with `pready_delay=2` | Both complete correctly under multi-cycle PREADY |
| **T11** | Backpressure | `bready`/`rready` held low for 15 cycles | Engine stalls in `RESP_STALL`; responses correctly released |
| **T12** | Error recovery | DECERR → SLVERR → normal write → normal read | Bridge returns to IDLE and operates normally after each error |

The testbench also reports:
- **Write/read latency** in clock cycles (from AW/AR handshake to B/R handshake)
- **Engine utilization** percentage (cycles in non-IDLE states)
- **Arbiter statistics** — total write grants, total read grants, maximum consecutive write streak

### 10.2 UVM Test Suite

#### `cfs_bridge_test_reg_access` (default)

Runs the `cfs_bridge_virtual_sequence` which exercises:

| Phase | Sequence | Transactions | Details |
|-------|----------|--------------|---------|
| 1 | `axi_sequence_rw` | 6 write+read pairs | `num_trans=6`, `addr_stride=4` |
| 2 | `axi_write_stress_seq` | 20 writes | No delays, back-to-back |
| 3 | `axi_write_slow_master_seq` | 8 writes | Large delays between AW, W, B |
| 4 | `axi_write_random_delay_seq` | 20 writes | Fully randomized timing |

#### `cfs_bridge_address_align_vseq`
- **Purpose:** Verify correct address propagation for all byte alignments
- **Transactions:** 50 read+write pairs
- **Key constraints:** `addr[1:0]` ∈ {0,1,2,3}; `size` ∈ {0,1,2}; `len` ∈ [0:3]

#### `cfs_bridge_burst_variation_vseq`
- **Purpose:** Stress test burst length and data width combinations
- **Transactions:** 30 transactions
- **Key constraints:** `len` ∈ [0:15]; `size` ∈ {0,1,2}; full random data values

#### `cfs_bridge_narrow_full_band_vseq`
- **Purpose:** Verify narrow (8/16-bit) and full (32-bit) write strobes
- **Transactions:** 50 transactions
- **Key constraints:** `size` ∈ {0,1,2}; `wstrb` ∈ [0x1:0xF]; word-aligned addresses

---

## 11. Scoreboard & Coverage

### Scoreboard Verification Logic

```
AXI Monitor → axi_queue
APB Monitor → apb_queue

For each AXI transaction popped from axi_queue:
  expected_beats = axi_tr.len + 1
  For beat i in [0 .. expected_beats-1]:
    apb_tr = apb_queue.pop_front()
    CHECK: apb_tr.dir      == axi_tr.is_write
    CHECK: apb_tr.addr     == axi_tr.addr + i*4
    CHECK: (if write) apb_tr.wdata == axi_tr.data_ary[i]
    CHECK: (if read)  apb_tr.rdata == axi_tr.data_ary[i]
```

### Functional Coverage

Implemented in `axi_coverage_subscriber` (connected to AXI monitor analysis port):

| Coverpoint | Bins |
|------------|------|
| `cp_direction` | write, read |
| `cp_len` | single-beat (0), short burst (1–7), long burst (8–15) |
| `cp_size` | 1B, 2B, 4B |
| `cross_dir_size` | 2 × 3 = 6 cross-product bins |

---

## 12. Simulation Flow

### 12.1 Makefile Targets

The project uses **Cadence Xcelium** (`xrun`). Simulation is configured with:
- `-64bit -access +rwc` — 64-bit mode with full signal access
- `-coverage all -covoverwrite` — enable and overwrite coverage database
- `-uvm -uvmhome CDNS-1.2` — UVM 1.2 support

| Target | Command | Description |
|--------|---------|-------------|
| `make all` | `make` | Compile + run (default) |
| `make compile` | `make compile` | Compile and elaborate only |
| `make run` | `make run` | Compile then simulate |
| `make gui` | `make gui` | Compile then launch SimVision GUI |
| `make show_files` | `make show_files` | Print all source files in compile order |
| `make clean` | `make clean` | Remove all simulation artifacts |

**Source compile order (enforced by Makefile):**

```
1. design/design.sv          (RTL)
2. axi_vip/axi_if.sv         (Interfaces — before packages)
3. apb_vip/cfs_apb_if.sv
4. packages/cfs_apb_pkg.sv   (UVM packages — before components)
5. packages/cfs_bridge_pkg.sv
6. packages/cfs_bridge_test_pkg.sv
7. testbench/axi_apb_bridge_tb_top.sv   (TB top — last)
```

### 12.2 Running a Specific Test

The UVM test name is passed via the `UVM_TEST` make variable:

```bash
# Run the default test
make run

# Run a specific test by name
make run UVM_TEST=cfs_bridge_test_reg_access

# Compile only (no simulation)
make compile

# Open GUI for waveform debugging
make gui

# Clean all outputs before a fresh run
make clean && make run
```

---

## 13. Waveform and Debug

The standalone testbench (`tb_bridge.sv`) dumps:

```systemverilog
$dumpfile("dump.vcd");
$dumpvars(1, tb_integrated_bridge);
$dumpvars(1, tb_integrated_bridge.u_dut);
```

The UVM testbench (`axi_apb_bridge_tb_top.sv`) dumps:

```systemverilog
$dumpfile("axi_apb_bridge_tb.vcd");
$dumpvars(0, axi_apb_bridge_tb_top);
```

**Useful debug probes** (wired directly in `tb_bridge.sv`):

| Probe | Signal path | Description |
|-------|-------------|-------------|
| `fsm_state` | `u_dut.u_engine.apb_state` | Current APB FSM state (4-bit) |
| `dbg_wr_grant` | `u_dut.wr_grant` | Write grant from arbiter |
| `dbg_rd_grant` | `u_dut.rd_grant` | Read grant from arbiter |
| `dbg_idle` | `u_dut.engine_idle` | Engine in IDLE state |

**APB protocol checker** (inline monitor in `tb_bridge.sv`):

```systemverilog
always @(posedge clk)
  if (rst_n && penable && !(|psel))
    $display("[APB-MON] t=%0t PENABLE w/o PSEL", $time);
```

---

## 14. Known Limitations

- **Single-beat only** — The bridge handles `arlen=0` / `awlen=0` (single-beat) AXI transactions. Multi-beat burst support (INCR, WRAP) on the AXI side would require a per-beat APB transaction loop and address incrementer inside the transaction engine.
- **No outstanding transactions** — Only one transaction is active in the APB engine at a time. AXI allows multiple outstanding transactions by ID; this bridge serializes all traffic through one APB port.
- **No QoS support** — AXI QoS signals (`AWQOS`, `ARQOS`) are not connected.
- **WRAP burst unsupported** — AXI WRAP burst type is not handled; only INCR is tested.
- **pstrb not verified at APB** — Write byte strobe is propagated through the bridge but not individually checked in the scoreboard against per-byte data.
- **Separate APB clock** — The current testbench ties APB clock to AXI clock. Asynchronous APB clock support would require CDC handling in the bridge.

---

## 15. Future Enhancements

- Add multi-beat burst support with internal address incrementer
- Add AXI ID-based out-of-order response support
- Extend the scoreboard to verify byte-lane-level data integrity using `WSTRB`
- Add a UVM register model (`uvm_reg_block`) to abstract APB register access
- Add formal property verification (FPV) assertions for APB protocol compliance
- Add power-aware simulation with UPF/CPF for the low-power APB domain
- Implement asynchronous clock domain crossing between AXI and APB clocks
- Add coverage-driven closure loop with a regression script
- Extend to support AMBA APB5 features (`PPROT`, `PAUSER`)