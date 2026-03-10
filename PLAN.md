# PCIe 1.0 Verilog Implementation Plan

> **Toolchain**: Icarus Verilog (`iverilog`) + GTKWave for waveform viewing  
> **Standard**: PCI Express Base Specification 1.0a / 1.1  
> **Target**: Synthesizable RTL for a PCIe 1.0 ×1 Endpoint, with a behavioral testbench  

---

## Table of Contents

1. [Project Goals and Scope](#1-project-goals-and-scope)
2. [Directory Structure](#2-directory-structure)
3. [Module Hierarchy](#3-module-hierarchy)
4. [Physical Layer Modules](#4-physical-layer-modules)
5. [Data Link Layer Modules](#5-data-link-layer-modules)
6. [Transaction Layer Modules](#6-transaction-layer-modules)
7. [Top-Level Integration](#7-top-level-integration)
8. [Testbench Architecture](#8-testbench-architecture)
9. [Test Cases](#9-test-cases)
10. [Build and Simulation Flow](#10-build-and-simulation-flow)
11. [Verification Plan](#11-verification-plan)
12. [Implementation Milestones](#12-implementation-milestones)

---

## 1. Project Goals and Scope

### 1.1 Goals

1. Implement a PCIe 1.0 ×1 **Endpoint (EP)** in synthesizable Verilog.
2. Implement a **Root Complex (RC) behavioral model** for testbench purposes (non-synthesizable BFM).
3. Verify the implementation using **Icarus Verilog (iverilog)** and **VCD waveform dumps** for GTKWave.
4. Cover the three PCIe layers: Physical, Data Link, and Transaction.

### 1.2 Scope

| In Scope                                              | Out of Scope                               |
|-------------------------------------------------------|--------------------------------------------|
| PCIe 1.0 ×1 single-lane Endpoint                     | Multi-lane (×4, ×8, ×16) bonding           |
| 8b/10b encoding/decoding                              | Physical analog PHY (SerDes)               |
| LFSR-based scrambling/descrambling                    | PCIe 2.0 / 3.0 / 4.0 (higher speed)       |
| LTSSM (Detect → Polling → Config → L0 → L0s → L1)   | PCIe Switch implementation                 |
| TLP generation/parsing (MRd, MWr, CplD, Cfg)         | PCIe-to-PCI bridge                         |
| ACK/NAK retry protocol                                | SR-IOV, ARI                                |
| Flow control (InitFC, UpdateFC)                       | Multi-root                                 |
| INTx emulation and MSI                               | MSI-X                                      |
| Configuration Space (Type 0, 4KB)                     | Isochronous TCs (TC1–TC7)                  |
| AER (Advanced Error Reporting) capability             | Power budgeting                            |

### 1.3 Assumptions

- The simulation uses a **bit-accurate** but **not cycle-accurate** parallel interface between layers (real PCIe uses high-speed serial; simulation uses parallel word buses for practical simulation speed).
- The PHY serializer/deserializer (SerDes) is represented by a **parallel-to-serial** and **serial-to-parallel** behavioral shim.
- Clock: 250 MHz system clock (= 1 clock per 8b/10b symbol period at 2.5 Gb/s).

---

## 2. Directory Structure

```
pcie-pr/
├── rtl/
│   ├── phy/
│   │   ├── pcie_phy_tx.v           # Physical Layer Transmitter
│   │   ├── pcie_phy_rx.v           # Physical Layer Receiver
│   │   ├── pcie_8b10b_enc.v        # 8b/10b Encoder
│   │   ├── pcie_8b10b_dec.v        # 8b/10b Decoder
│   │   ├── pcie_scrambler.v        # LFSR Scrambler (TX)
│   │   ├── pcie_descrambler.v      # LFSR Descrambler (RX)
│   │   └── pcie_ltssm.v            # Link Training and Status State Machine
│   ├── dll/
│   │   ├── pcie_dll_tx.v           # DLL Transmitter (seq#, LCRC, replay buffer)
│   │   ├── pcie_dll_rx.v           # DLL Receiver (LCRC check, ACK/NAK)
│   │   ├── pcie_crc32.v            # CRC-32 computation (LCRC / ECRC)
│   │   ├── pcie_crc16.v            # CRC-16 computation (DLLP CRC)
│   │   ├── pcie_replay_buffer.v    # Replay buffer (FIFO + replay logic)
│   │   └── pcie_flow_ctrl.v        # Flow control credit manager
│   ├── tl/
│   │   ├── pcie_tl_tx.v            # TL Transmitter (TLP builder)
│   │   ├── pcie_tl_rx.v            # TL Receiver (TLP parser/router)
│   │   ├── pcie_tlp_encoder.v      # TLP header encoder
│   │   ├── pcie_tlp_decoder.v      # TLP header decoder
│   │   ├── pcie_cfg_space.v        # Configuration Space register file
│   │   ├── pcie_completion_tracker.v # Outstanding request / completion matching
│   │   └── pcie_msi.v              # MSI interrupt generation
│   └── top/
│       └── pcie_endpoint.v         # Top-level PCIe Endpoint integration
├── tb/
│   ├── bfm/
│   │   ├── pcie_rc_bfm.v           # Root Complex Bus Functional Model
│   │   ├── pcie_link_model.v       # Bidirectional link interconnect model
│   │   └── pcie_monitor.v          # Transaction monitor / checker
│   ├── tc/
│   │   ├── tc_8b10b.v              # Test: 8b/10b encode/decode
│   │   ├── tc_scrambler.v          # Test: scramble/descramble round-trip
│   │   ├── tc_ltssm.v              # Test: LTSSM training sequence
│   │   ├── tc_ack_nak.v            # Test: ACK/NAK retry protocol
│   │   ├── tc_flow_ctrl.v          # Test: Flow control credits
│   │   ├── tc_mem_write.v          # Test: Memory Write TLP
│   │   ├── tc_mem_read.v           # Test: Memory Read TLP + CplD
│   │   ├── tc_cfg_access.v         # Test: Configuration Read/Write
│   │   ├── tc_msi.v                # Test: MSI interrupt
│   │   └── tc_error_handling.v     # Test: Error injection and reporting
│   └── tb_top.v                    # Top-level testbench instantiation
├── scripts/
│   ├── run_all.sh                  # Run all test cases
│   ├── run_tc.sh                   # Run a single test case
│   └── view_waves.sh               # Open GTKWave with VCD
├── PCIE1.md                        # PCIe 1.0 protocol study
├── PLAN.md                         # This implementation plan
└── README.md                       # Project overview
```

---

## 3. Module Hierarchy

```
pcie_endpoint (top/pcie_endpoint.v)
├── pcie_phy_tx      (phy/pcie_phy_tx.v)
│   ├── pcie_scrambler   (phy/pcie_scrambler.v)
│   └── pcie_8b10b_enc   (phy/pcie_8b10b_enc.v)
├── pcie_phy_rx      (phy/pcie_phy_rx.v)
│   ├── pcie_8b10b_dec   (phy/pcie_8b10b_dec.v)
│   └── pcie_descrambler (phy/pcie_descrambler.v)
├── pcie_ltssm       (phy/pcie_ltssm.v)
├── pcie_dll_tx      (dll/pcie_dll_tx.v)
│   ├── pcie_crc32       (dll/pcie_crc32.v)
│   └── pcie_replay_buffer (dll/pcie_replay_buffer.v)
├── pcie_dll_rx      (dll/pcie_dll_rx.v)
│   └── pcie_crc32       (dll/pcie_crc32.v)
├── pcie_crc16       (dll/pcie_crc16.v)
├── pcie_flow_ctrl   (dll/pcie_flow_ctrl.v)
├── pcie_tl_tx       (tl/pcie_tl_tx.v)
│   └── pcie_tlp_encoder (tl/pcie_tlp_encoder.v)
├── pcie_tl_rx       (tl/pcie_tl_rx.v)
│   └── pcie_tlp_decoder (tl/pcie_tlp_decoder.v)
├── pcie_cfg_space   (tl/pcie_cfg_space.v)
├── pcie_completion_tracker (tl/pcie_completion_tracker.v)
└── pcie_msi         (tl/pcie_msi.v)
```

---

## 4. Physical Layer Modules

### 4.1 `pcie_8b10b_enc.v` — 8b/10b Encoder

**Function**: Converts 8-bit data bytes and K-code control symbols into 10-bit 8b/10b encoded symbols, maintaining DC balance via Running Disparity (RD).

**Interface**:
```verilog
module pcie_8b10b_enc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  data_in,     // 8-bit input byte
    input  wire        k_in,        // 1 = K-code (control symbol)
    input  wire        valid_in,    // Input valid
    output reg  [9:0]  data_out,    // 10-bit encoded symbol
    output reg         valid_out,   // Output valid
    output reg         rd_out       // Running disparity after this symbol
);
```

**Implementation Notes**:
- Implement the full 256-entry lookup table for Dx.y symbols plus all valid K-code entries.
- Maintain Running Disparity (RD) state: RD=-1 (initial) means use RD- encoding; RD=+1 means use RD+ encoding.
- Two sub-tables: 5b/6b encoding of bits [4:0] (abcde → fghjik), 3b/4b encoding of bits [7:5] (fgh → ghij).
- **K28.5 (0xBC)** is the comma character used for synchronization.
- Table values sourced from IEEE 802.3 / 8b/10b standard.

**Key K-codes used in PCIe**:
```
K28.5 = 10'b0101111100 (RD-) / 10'b1010000011 (RD+)  — COM
K27.7 = 10'b1110101000 (RD-) / 10'b0001010111 (RD+)  — STP (Start TLP)
K28.2 = 10'b0010111100 (RD-) / 10'b1101000011 (RD+)  — SDP (Start DLLP)
K29.7 = 10'b1010111000 (RD-) / 10'b0101000111 (RD+)  — END
K30.7 = 10'b1100101000 (RD-) / 10'b0011010111 (RD+)  — EDB
K23.7 = 10'b1110110100 (RD-) / 10'b0001001011 (RD+)  — PAD
```

### 4.2 `pcie_8b10b_dec.v` — 8b/10b Decoder

**Function**: Converts 10-bit encoded symbols back to 8-bit data bytes or K-codes. Detects disparity errors and invalid symbols.

**Interface**:
```verilog
module pcie_8b10b_dec (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [9:0]  data_in,      // 10-bit encoded symbol
    input  wire        valid_in,
    output reg  [7:0]  data_out,     // Decoded 8-bit byte
    output reg         k_out,        // 1 = K-code
    output reg         valid_out,
    output reg         disp_err,     // Disparity error detected
    output reg         code_err      // Invalid code word
);
```

**Implementation Notes**:
- Reverse-lookup 10-bit → 8-bit + K flag.
- Track RD and flag disparity violations.
- Flag unrecognized 10-bit patterns as code errors (receiver errors reported to AER).

### 4.3 `pcie_scrambler.v` / `pcie_descrambler.v` — LFSR Scrambler

**Function**: Applies/removes scrambling using a 16-bit LFSR per the PCIe 1.0 specification.

**Polynomial**: `x^16 + x^5 + x^4 + x^3 + 1`  
**Seed**: `0xFFFF`  
**Reset**: At start of each packet (after STP/SDP K-code).

**Interface**:
```verilog
module pcie_scrambler (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        enable,       // Scrambling enable (from LTSSM)
    input  wire        sof,          // Start of frame — reset LFSR
    input  wire [7:0]  data_in,
    input  wire        valid_in,
    output reg  [7:0]  data_out,
    output reg         valid_out
);
```

**Implementation Notes**:
- LFSR feedback taps: bits 15, 4, 3, 2 (0-indexed from LSB).
- XOR each input byte with the current LFSR output byte.
- Advance LFSR 8 times per byte processed.
- K-codes (STP, SDP, END, EDB, PAD, COM) are **never scrambled** — pass through as-is.
- The scrambler is reset by K28.5 (COM) at the start of each link training ordered set.

### 4.4 `pcie_ltssm.v` — Link Training and Status State Machine

**Function**: Controls the PCIe link lifecycle from power-on detect through training and operational state.

**Interface**:
```verilog
module pcie_ltssm (
    input  wire        clk,
    input  wire        rst_n,
    // Physical signals
    input  wire        rx_detect,    // Receiver detected (from analog)
    input  wire [9:0]  rx_symbol,    // Received 10-bit symbol from PHY RX
    input  wire        rx_valid,
    input  wire        rx_elec_idle, // Electrical idle on RX
    output reg  [9:0]  tx_symbol,    // Transmit symbol to PHY TX
    output reg         tx_valid,
    output reg         tx_elec_idle, // Drive TX to electrical idle
    // Link status
    output reg  [3:0]  ltssm_state,  // Current LTSSM state
    output reg         link_up,      // Link in L0 (operational)
    output reg         link_reset,   // Hot reset detected
    // Config from/to DLL
    input  wire        dll_up,       // DLL initialized
    output reg         phy_reset,    // Reset all layers above PHY
    // Scrambling control
    output reg         scramble_en   // Enable scrambling
);
```

**LTSSM State Encoding**:
```verilog
localparam LTSSM_DETECT_QUIET    = 4'h0;
localparam LTSSM_DETECT_ACTIVE   = 4'h1;
localparam LTSSM_POLLING_ACTIVE  = 4'h2;
localparam LTSSM_POLLING_CONFIG  = 4'h3;
localparam LTSSM_CONFIG_LINKWD_S = 4'h4;
localparam LTSSM_CONFIG_LINKWD_A = 4'h5;
localparam LTSSM_CONFIG_LANENUM  = 4'h6;
localparam LTSSM_CONFIG_COMPLETE = 4'h7;
localparam LTSSM_CONFIG_IDLE     = 4'h8;
localparam LTSSM_L0              = 4'h9;
localparam LTSSM_L0S_TX          = 4'hA;
localparam LTSSM_L0S_RX          = 4'hB;
localparam LTSSM_L1              = 4'hC;
localparam LTSSM_RECOVERY_RXLOCK = 4'hD;
localparam LTSSM_RECOVERY_RCFG   = 4'hE;
localparam LTSSM_HOT_RESET       = 4'hF;
```

**Ordered Set Transmission**:
- In **Polling.Active**: Transmit TS1 ordered sets (16 symbols: K28.5, Link#=PAD, Lane#=PAD, ...).
- In **Config**: Transmit TS2 ordered sets with negotiated Link/Lane numbers.
- In **L0s exit**: Transmit FTS ordered sets (quantity = N_FTS from training).

**TS1/TS2 Detection Logic**:
- Detect K28.5 followed by valid TS pattern.
- Count consecutive received TS1s (need 8 consecutive).
- Count consecutive received TS2s (need 8 consecutive) to confirm transition.

### 4.5 `pcie_phy_tx.v` — Physical Layer Transmitter

**Function**: Top-level PHY TX: accepts byte stream from DLL, applies scrambling and 8b/10b encoding, outputs serial (or parallel for simulation).

**Interface**:
```verilog
module pcie_phy_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scramble_en,
    input  wire        link_up,
    // From DLL
    input  wire [7:0]  tx_data,      // Byte from DLL
    input  wire        tx_k,         // K-code flag
    input  wire        tx_valid,
    output wire        tx_ready,
    // To SerDes (parallel for simulation)
    output wire [9:0]  phy_tx_data,
    output wire        phy_tx_valid
);
```

### 4.6 `pcie_phy_rx.v` — Physical Layer Receiver

**Function**: Top-level PHY RX: receives encoded symbols, performs 8b/10b decoding and descrambling, outputs byte stream to DLL.

**Interface**:
```verilog
module pcie_phy_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        scramble_en,
    input  wire        link_up,
    // From SerDes
    input  wire [9:0]  phy_rx_data,
    input  wire        phy_rx_valid,
    // To DLL
    output reg  [7:0]  rx_data,
    output reg         rx_k,
    output reg         rx_valid,
    // Error signals
    output reg         rx_err_disp,
    output reg         rx_err_code
);
```

---

## 5. Data Link Layer Modules

### 5.1 `pcie_crc32.v` — CRC-32 Computation

**Function**: Computes 32-bit CRC over arbitrary byte streams (used for LCRC and ECRC).

**Polynomial**: `0x04C11DB7` (same as Ethernet CRC-32)  
**Initial value**: `0xFFFFFFFF`  
**Final XOR**: `0xFFFFFFFF`  
**Bit order**: LSB-first (reflected)

**Interface**:
```verilog
module pcie_crc32 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        init,         // Assert to reset CRC to 0xFFFFFFFF
    input  wire [7:0]  data_in,
    input  wire        valid_in,
    output reg  [31:0] crc_out       // Running CRC value; XOR with 0xFFFFFFFF for final
);
```

**Implementation Notes**:
- Implement using the standard parallel CRC computation (Galois LFSR unrolled).
- Provide a combinational version for latency-critical paths.
- LCRC covers: Sequence Number (2 bytes) + TLP Header + Data Payload.

### 5.2 `pcie_crc16.v` — CRC-16 Computation (DLLP)

**Function**: Computes 16-bit CRC over DLLP bytes.

**Polynomial**: `0x100B` (from PCIe spec)  
**Initial value**: `0xFFFF`  
**Final XOR**: `0xFFFF`

**Interface**:
```verilog
module pcie_crc16 (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        init,
    input  wire [7:0]  data_in,
    input  wire        valid_in,
    output reg  [15:0] crc_out
);
```

### 5.3 `pcie_replay_buffer.v` — Replay Buffer

**Function**: Stores transmitted but unacknowledged TLPs. Replays them on NAK or timeout.

**Parameters**:
```verilog
parameter REPLAY_BUF_DEPTH = 4096;   // Bytes
parameter SEQ_NUM_WIDTH    = 12;      // 12-bit sequence numbers
parameter REPLAY_TIMEOUT   = 200000; // Clock cycles (~800µs at 250MHz)
parameter MAX_REPLAY_NUM   = 3;       // Max retries before fatal error
```

**Interface**:
```verilog
module pcie_replay_buffer (
    input  wire        clk,
    input  wire        rst_n,
    // Write port (from DLL TX, new TLPs)
    input  wire [7:0]  wr_data,
    input  wire        wr_tlp_start, // Start of TLP (seq# is in wr_data)
    input  wire        wr_tlp_end,   // End of TLP
    input  wire        wr_valid,
    // ACK/NAK interface
    input  wire [11:0] ack_seqnum,   // Sequence number being ACKed
    input  wire        ack_valid,
    input  wire [11:0] nak_seqnum,   // Sequence number being NAKed
    input  wire        nak_valid,
    // Replay read port (to DLL TX)
    output reg  [7:0]  rd_data,
    output reg         rd_tlp_start,
    output reg         rd_tlp_end,
    output reg         rd_valid,
    input  wire        rd_ready,
    // Status
    output reg         replay_active,
    output reg         replay_timeout_err,
    output reg         max_replay_err
);
```

**Implementation Notes**:
- Implement as a circular FIFO keyed by TLP sequence numbers.
- Track the oldest unacknowledged sequence number (ACKD_SEQ).
- On ACK: advance ACKD_SEQ to ack_seqnum, freeing those buffer entries.
- On NAK: set replay pointer to nak_seqnum + 1 and assert replay_active.
- On timeout: set replay pointer to ACKD_SEQ + 1 and replay.

### 5.4 `pcie_dll_tx.v` — Data Link Layer Transmitter

**Function**: Adds sequence numbers, computes LCRC, schedules TLPs and DLLPs for transmission.

**Interface**:
```verilog
module pcie_dll_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        link_up,
    // From TL (TLPs)
    input  wire [7:0]  tlp_data,
    input  wire        tlp_start,
    input  wire        tlp_end,
    input  wire        tlp_valid,
    output wire        tlp_ready,
    // DLLP from FC module
    input  wire [31:0] dllp_data,    // 4 bytes of DLLP payload
    input  wire        dllp_valid,
    output wire        dllp_ready,
    // To PHY TX
    output reg  [7:0]  phy_data,
    output reg         phy_k,
    output reg         phy_valid,
    input  wire        phy_ready,
    // ACK/NAK feedback from DLL RX
    input  wire [11:0] ack_seqnum,
    input  wire        ack_valid,
    input  wire [11:0] nak_seqnum,
    input  wire        nak_valid,
    // Errors
    output reg         dll_tx_err
);
```

**Transmission Format**:
```
[K27.7 STP] [Seq[11:8]/0000] [Seq[7:0]] [TLP bytes...] [LCRC[31:24]] [LCRC[23:16]] [LCRC[15:8]] [LCRC[7:0]] [K29.7 END]
```

**DLLP Transmission Format**:
```
[K28.2 SDP] [DLLP_byte0] [DLLP_byte1] [DLLP_byte2] [DLLP_byte3] [CRC16_MSB] [CRC16_LSB] [K29.7 END]
```

**Arbitration**: TLPs take priority over UpdateFC DLLPs (but InitFC DLLPs have highest priority before link is up).

### 5.5 `pcie_dll_rx.v` — Data Link Layer Receiver

**Function**: Strips framing, verifies LCRC, checks sequence numbers, generates ACK/NAK DLLPs.

**Interface**:
```verilog
module pcie_dll_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        link_up,
    // From PHY RX
    input  wire [7:0]  phy_data,
    input  wire        phy_k,
    input  wire        phy_valid,
    // To TL (valid TLPs)
    output reg  [7:0]  tlp_data,
    output reg         tlp_start,
    output reg         tlp_end,
    output reg         tlp_valid,
    // To FC module (DLLPs)
    output reg  [31:0] dllp_data,
    output reg         dllp_valid,
    // ACK/NAK generation (to DLL TX)
    output reg  [11:0] ack_seqnum,
    output reg         ack_req,
    output reg  [11:0] nak_seqnum,
    output reg         nak_req,
    // Errors
    output reg         lcrc_err,
    output reg         seq_err,
    output reg         framing_err
);
```

**Expected Sequence Number**: Track NEXT_RCV_SEQ (next expected sequence number). If received TLP has seq ≠ NEXT_RCV_SEQ, send NAK.

### 5.6 `pcie_flow_ctrl.v` — Flow Control Manager

**Function**: Manages flow control credits for all three TLP classes (Posted, Non-Posted, Completion) on both TX and RX sides.

**Parameters**:
```verilog
parameter P_HDR_CREDITS  = 8'd32;   // Posted header credits advertised
parameter P_DAT_CREDITS  = 12'd64;  // Posted data credits advertised (×4 bytes)
parameter NP_HDR_CREDITS = 8'd8;
parameter NP_DAT_CREDITS = 12'd0;   // Non-posted no data (reads have no payload)
parameter CPL_HDR_CREDITS = 8'd8;
parameter CPL_DAT_CREDITS = 12'd64;
```

**Interface**:
```verilog
module pcie_flow_ctrl (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        link_up,
    // Init FC (RX: receive remote init, TX: send our init)
    output reg  [31:0] initfc1_dllp, // InitFC1 DLLP to send
    output reg         initfc1_valid,
    output reg  [31:0] initfc2_dllp, // InitFC2 DLLP to send
    output reg         initfc2_valid,
    // Received InitFC/UpdateFC from remote
    input  wire [31:0] rx_dllp,
    input  wire        rx_dllp_valid,
    // TLP admission control (TX path)
    input  wire  [1:0] tx_tlp_class, // 0=P, 1=NP, 2=Cpl
    input  wire  [7:0] tx_hdr_dw,    // Header DW count
    input  wire  [9:0] tx_data_dw,   // Data DW count
    output wire        tx_fc_ok,     // Permission to transmit
    input  wire        tx_tlp_sent,  // TLP was transmitted, consume credits
    // RX credit return
    input  wire  [1:0] rx_tlp_class,
    input  wire  [7:0] rx_hdr_dw,
    input  wire  [9:0] rx_data_dw,
    input  wire        rx_tlp_rcvd,  // TLP received, return credits
    // UpdateFC DLLP generation
    output reg  [31:0] updatefc_dllp,
    output reg         updatefc_valid
);
```

---

## 6. Transaction Layer Modules

### 6.1 `pcie_tlp_encoder.v` — TLP Header Encoder

**Function**: Builds TLP headers from structured field inputs.

**Interface**:
```verilog
module pcie_tlp_encoder (
    input  wire        clk,
    input  wire        rst_n,
    // Common fields
    input  wire  [4:0] tlp_type,     // TLP type field (Fmt[1:0] and Type[4:0])
    input  wire  [2:0] tc,           // Traffic Class
    input  wire  [1:0] attr,         // Attributes (RO, NS)
    input  wire  [9:0] length,       // Payload length in DW
    input  wire [15:0] req_id,       // Requester ID
    input  wire  [7:0] tag,          // Transaction tag
    input  wire  [3:0] last_be,      // Last DW byte enable
    input  wire  [3:0] first_be,     // First DW byte enable
    input  wire [63:0] address,      // Target address
    input  wire        addr_64bit,   // Use 64-bit address
    input  wire        valid_in,
    // Output TLP header stream
    output reg  [7:0]  hdr_data,
    output reg         hdr_valid,
    output reg         hdr_last,     // Last byte of header
    output reg  [2:0]  hdr_dw_cnt   // Number of DWs in header (3 or 4)
);
```

### 6.2 `pcie_tlp_decoder.v` — TLP Header Decoder

**Function**: Parses incoming TLP byte stream into structured fields.

**Interface**:
```verilog
module pcie_tlp_decoder (
    input  wire        clk,
    input  wire        rst_n,
    // Input byte stream (from DLL)
    input  wire  [7:0] data_in,
    input  wire        tlp_start,
    input  wire        tlp_end,
    input  wire        valid_in,
    // Decoded header fields
    output reg   [1:0] fmt,
    output reg   [4:0] tlp_type,
    output reg   [2:0] tc,
    output reg   [1:0] attr,
    output reg   [9:0] length,
    output reg  [15:0] req_id,
    output reg   [7:0] tag,
    output reg   [3:0] last_be,
    output reg   [3:0] first_be,
    output reg  [63:0] address,
    output reg  [15:0] cpl_id,      // Completer ID (for Cpl/CplD)
    output reg   [2:0] cpl_status,
    output reg  [11:0] byte_count,
    output reg   [6:0] lower_addr,
    output reg         ep,           // Poisoned TLP
    output reg         td,           // TLP Digest present
    // Data payload
    output reg   [7:0] data_out,
    output reg         data_valid,
    output reg         data_last,
    // Header decoded flag
    output reg         hdr_valid,    // Header completely decoded
    output reg         err_malformed // Malformed TLP detected
);
```

### 6.3 `pcie_cfg_space.v` — Configuration Space

**Function**: Implements the 4096-byte PCIe Configuration Space register file for the Endpoint.

**Register Map (first 64 bytes)**:
```
0x000: Vendor ID [15:0] / Device ID [31:16]
0x004: Command [15:0] / Status [31:16]
0x008: Revision ID [7:0] / Class Code [31:8]
0x00C: Cache Line Size [7:0] / Reserved / Header Type [23:16] / BIST [31:24]
0x010: BAR0 (Memory BAR, 32-bit, 4KB minimum)
0x014: BAR1 (I/O BAR)
0x018: BAR2 (Memory BAR, 64-bit low)
0x01C: BAR3 (Memory BAR, 64-bit high)
0x020: BAR4
0x024: BAR5
0x028: CardBus CIS Pointer
0x02C: Subsystem Vendor ID / Subsystem ID
0x030: Expansion ROM BAR
0x034: Capabilities Pointer (= 0x40)
0x038: Reserved
0x03C: Interrupt Line / Interrupt Pin (= 0x01) / Min_Grant / Max_Latency
0x040: PCIe Capability (ID=0x10, Next=0x60)
0x044: Device Capabilities
0x048: Device Control / Device Status
0x04C: Link Capabilities
0x050: Link Control / Link Status
0x060: MSI Capability (ID=0x05, Next=0x00)
...
0x100–0xFFF: Extended capabilities (AER at 0x100)
```

**Interface**:
```verilog
module pcie_cfg_space #(
    parameter VENDOR_ID  = 16'hBEEF,
    parameter DEVICE_ID  = 16'h1234,
    parameter CLASS_CODE = 24'hFF0000,  // Unclassified device
    parameter BAR0_MASK  = 32'hFFFF0000 // 64KB BAR0
) (
    input  wire        clk,
    input  wire        rst_n,
    // PCIe Config access from TL
    input  wire [11:0] cfg_addr,     // Byte address within config space
    input  wire [31:0] cfg_wdata,
    input  wire  [3:0] cfg_be,
    input  wire        cfg_wr,
    input  wire        cfg_rd,
    output reg  [31:0] cfg_rdata,
    output reg         cfg_done,
    // Outputs to rest of design
    output reg  [2:0]  max_payload,  // MaxPayloadSize setting
    output reg  [2:0]  max_rd_req,   // MaxReadRequestSize setting
    output reg         bus_master_en,
    output reg         mem_space_en,
    output reg         io_space_en,
    output reg  [31:0] bar0_base,
    output reg  [31:0] bar1_base,
    output reg  [7:0]  int_line,
    output reg         msi_enable,
    output reg  [63:0] msi_addr,
    output reg  [15:0] msi_data,
    output reg  [2:0]  msi_multi_cap
);
```

### 6.4 `pcie_completion_tracker.v` — Completion Tracker

**Function**: Tracks outstanding non-posted requests and matches incoming completions to them.

**Parameters**:
```verilog
parameter MAX_TAGS = 32;   // Maximum outstanding requests
parameter TIMEOUT_CYCLES = 500000; // Completion timeout (~2ms at 250MHz)
```

**Interface**:
```verilog
module pcie_completion_tracker (
    input  wire        clk,
    input  wire        rst_n,
    // Request tracking (allocate tag)
    input  wire  [7:0] req_tag,
    input  wire  [9:0] req_length,   // Expected completion data length
    input  wire [63:0] req_addr,
    input  wire        req_valid,
    output wire        req_ready,    // Tag available
    // Completion received
    input  wire  [7:0] cpl_tag,
    input  wire  [9:0] cpl_length,
    input  wire  [2:0] cpl_status,
    input  wire        cpl_valid,
    // To application (matched completion)
    output reg   [7:0] out_tag,
    output reg  [63:0] out_addr,
    output reg   [2:0] out_status,
    output reg         out_valid,
    // Timeout / error
    output reg         cpl_timeout,
    output reg  [7:0]  timeout_tag,
    output reg         unexpected_cpl
);
```

### 6.5 `pcie_tl_tx.v` — Transaction Layer Transmitter

**Function**: Accepts transaction requests from the application layer, encodes them as TLPs, and submits to DLL.

**Interface**:
```verilog
module pcie_tl_tx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        link_up,
    // Application interface
    input  wire  [2:0] req_type,     // 0=MRd,1=MWr,2=IORd,3=IOWr,4=CfgRd,5=CfgWr,6=Msg
    input  wire [63:0] req_addr,
    input  wire  [9:0] req_length,
    input  wire  [3:0] req_first_be,
    input  wire  [3:0] req_last_be,
    input  wire  [7:0] req_tag,
    input  wire [15:0] req_rid,
    input  wire [31:0] req_wdata,
    input  wire        req_valid,
    output wire        req_ready,
    // Completion TX (from application)
    input  wire [15:0] cpl_rid,
    input  wire  [7:0] cpl_tag,
    input  wire  [2:0] cpl_status,
    input  wire [31:0] cpl_data,
    input  wire  [9:0] cpl_length,
    input  wire        cpl_valid,
    output wire        cpl_ready,
    // To DLL
    output reg  [7:0]  dll_data,
    output reg         dll_tlp_start,
    output reg         dll_tlp_end,
    output reg         dll_valid,
    input  wire        dll_ready,
    // Flow control
    input  wire        fc_ok,
    output wire  [1:0] fc_class,
    output wire  [7:0] fc_hdr_dw,
    output wire  [9:0] fc_data_dw
);
```

### 6.6 `pcie_tl_rx.v` — Transaction Layer Receiver

**Function**: Parses incoming TLPs from DLL and routes them to the appropriate handler (config, memory, completion).

**Interface**:
```verilog
module pcie_tl_rx (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        link_up,
    // From DLL
    input  wire  [7:0] dll_data,
    input  wire        dll_tlp_start,
    input  wire        dll_tlp_end,
    input  wire        dll_valid,
    // Configuration access output
    output reg  [11:0] cfg_addr,
    output reg  [31:0] cfg_wdata,
    output reg   [3:0] cfg_be,
    output reg         cfg_wr,
    output reg         cfg_rd,
    input  wire [31:0] cfg_rdata,
    input  wire        cfg_done,
    // Memory write to application
    output reg  [63:0] mem_wr_addr,
    output reg  [31:0] mem_wr_data,
    output reg   [3:0] mem_wr_be,
    output reg         mem_wr_valid,
    // Memory read request (triggers completion generation)
    output reg  [63:0] mem_rd_addr,
    output reg   [9:0] mem_rd_length,
    output reg  [15:0] mem_rd_rid,
    output reg   [7:0] mem_rd_tag,
    output reg         mem_rd_valid,
    // Completion received (for outstanding requests)
    output reg  [15:0] cpl_rid,
    output reg   [7:0] cpl_tag,
    output reg   [2:0] cpl_status,
    output reg  [31:0] cpl_data,
    output reg   [9:0] cpl_length,
    output reg         cpl_valid,
    // Error
    output reg         err_ur,      // Unsupported Request
    output reg         err_ca,      // Completer Abort
    output reg         err_malformed
);
```

### 6.7 `pcie_msi.v` — MSI Interrupt Generator

**Function**: Generates MSI Memory Write TLPs when interrupt is asserted.

**Interface**:
```verilog
module pcie_msi (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        msi_enable,
    input  wire [63:0] msi_addr,
    input  wire [15:0] msi_data,
    input  wire  [2:0] msi_multi_cap,
    input  wire [15:0] my_rid,       // This function's Requester ID
    // Application interrupt assertion
    input  wire [4:0]  int_vec,      // Interrupt vector (0–31)
    input  wire        int_req,      // Assert interrupt
    output reg         int_ack,
    // To TL TX
    output reg  [63:0] tx_addr,
    output reg  [31:0] tx_data,
    output reg         tx_valid,
    input  wire        tx_ready
);
```

---

## 7. Top-Level Integration

### 7.1 `pcie_endpoint.v` — Top-Level Endpoint

```verilog
module pcie_endpoint #(
    parameter VENDOR_ID  = 16'hBEEF,
    parameter DEVICE_ID  = 16'h1234,
    parameter BAR0_MASK  = 32'hFFFF0000
) (
    input  wire        clk,          // 250 MHz system clock
    input  wire        rst_n,        // Active-low reset
    // PCIe Serial Interface (parallel for simulation)
    input  wire [9:0]  rx_data,      // 10-bit symbol from link
    input  wire        rx_valid,
    output wire [9:0]  tx_data,      // 10-bit symbol to link
    output wire        tx_valid,
    // Application Memory Interface
    output wire [31:0] app_mem_addr,
    output wire [31:0] app_mem_wdata,
    output wire  [3:0] app_mem_be,
    output wire        app_mem_wr,
    output wire        app_mem_rd,
    input  wire [31:0] app_mem_rdata,
    input  wire        app_mem_ready,
    // Application Interrupt
    input  wire        app_int_req,
    input  wire [4:0]  app_int_vec,
    output wire        app_int_ack,
    // Status
    output wire        link_up,
    output wire [3:0]  ltssm_state
);
```

---

## 8. Testbench Architecture

### 8.1 Overview

```
tb_top.v
├── pcie_endpoint (DUT — Device Under Test)
├── pcie_rc_bfm   (Root Complex BFM)
├── pcie_link_model (bidirectional link with optional error injection)
└── pcie_monitor  (transaction monitor/checker)
```

The testbench uses a **stimulus → DUT → response** pattern:
- **BFM** sends PCIe transactions (Memory Reads, Config Reads, etc.)
- **DUT** (pcie_endpoint) processes and responds
- **Monitor** observes and verifies all transactions

### 8.2 `pcie_rc_bfm.v` — Root Complex BFM

The RC BFM provides task-based API for sending/receiving PCIe transactions:

```verilog
// Tasks provided by BFM:

// Configuration access
task bfm_cfg_rd(input [15:0] bdf, input [11:0] addr, output [31:0] data);
task bfm_cfg_wr(input [15:0] bdf, input [11:0] addr, input [31:0] data, input [3:0] be);

// Memory transactions
task bfm_mem_rd(input [63:0] addr, input [9:0] length, output [31:0] data[]);
task bfm_mem_wr(input [63:0] addr, input [31:0] data[], input [3:0] first_be);

// Link training
task bfm_train_link();       // Simulates LTSSM from Detect through L0
task bfm_init_fc();          // Exchange InitFC DLLPs

// Error injection
task bfm_inject_bad_lcrc();  // Send TLP with corrupted LCRC
task bfm_inject_bad_seq();   // Send TLP with wrong sequence number
```

### 8.3 `pcie_link_model.v` — Link Interconnect

Provides a bidirectional connection between RC BFM and DUT with optional error injection:

```verilog
module pcie_link_model (
    input  wire        clk,
    // EP side
    input  wire [9:0]  ep_tx_data,
    output wire [9:0]  ep_rx_data,
    // RC side
    input  wire [9:0]  rc_tx_data,
    output wire [9:0]  rc_rx_data,
    // Error injection
    input  wire        inject_bit_err,  // Flip a bit in the next symbol
    input  wire        inject_edb,      // Replace END with EDB
    input  wire [7:0]  delay_cycles     // Propagation delay
);
```

### 8.4 `pcie_monitor.v` — Transaction Monitor

Observes all TLPs on the link and performs:
- TLP decode and display (`$display`)
- Sequence number continuity check
- Flow control credit accounting verification
- Ordered-set detection logging
- Error injection tracking

---

## 9. Test Cases

### TC-01: `tc_8b10b.v` — 8b/10b Encode/Decode

**Goal**: Verify that all 256 data codes and all valid K-codes encode and decode correctly, and that disparity is maintained.

**Steps**:
1. Instantiate `pcie_8b10b_enc` + `pcie_8b10b_dec` in loopback.
2. Send all 256 Dx.y values with initial RD=-1 and RD=+1.
3. Send all PCIe K-codes.
4. Verify decoded output == input and no error flags.
5. Inject an invalid 10-bit code; verify `code_err` asserted.

**Pass Criteria**: 0 mismatches, all K-codes recognized, invalid code flagged.

### TC-02: `tc_scrambler.v` — Scrambler Round-Trip

**Goal**: Verify that scrambling then descrambling recovers the original data.

**Steps**:
1. Instantiate `pcie_scrambler` + `pcie_descrambler`.
2. Send 256 pseudo-random bytes, assert `sof` periodically to test LFSR reset.
3. Verify descrambled output == original input.
4. Check that K-codes pass through unscrambled.

**Pass Criteria**: All bytes recover correctly, K-codes unchanged.

### TC-03: `tc_ltssm.v` — Link Training

**Goal**: Verify LTSSM correctly sequences from Detect through L0.

**Steps**:
1. Assert `rst_n` deasserted, `rx_detect` low.
2. Assert `rx_detect` (receiver present).
3. Simulate RC BFM transmitting TS1s (8+ consecutive).
4. BFM transitions to TS2; verify DUT also sends TS2.
5. After 8 consecutive TS2s, verify `link_up` asserted.
6. Verify `ltssm_state == LTSSM_L0`.

**Pass Criteria**: `link_up` asserts within 10,000 clock cycles of training start.

### TC-04: `tc_flow_ctrl.v` — Flow Control Initialization

**Goal**: Verify InitFC DLLP exchange and credit counting.

**Steps**:
1. After L0, verify DUT sends `InitFC1` DLLPs for P/NP/Cpl classes.
2. BFM sends its `InitFC1` and `InitFC2` DLLPs.
3. DUT responds with `InitFC2`.
4. Verify DUT is now allowed to send TLPs (FC credits available).
5. Send enough TLPs to consume all posted header credits.
6. Verify DUT stalls on next TLP (FC = 0).
7. BFM sends UpdateFC returning credits.
8. Verify DUT resumes sending.

**Pass Criteria**: Stall behavior correct, resume on credit return.

### TC-05: `tc_ack_nak.v` — ACK/NAK Retry Protocol

**Goal**: Verify replay buffer and NAK/timeout retry.

**Steps**:
1. BFM sends a configuration read TLP to DUT (triggers non-posted request).
2. Verify DUT sends a valid TLP with sequence number 0.
3. BFM sends NAK for sequence 0.
4. Verify DUT replays TLP with sequence 0.
5. BFM sends ACK for sequence 0.
6. Verify replay buffer entry freed.
7. Inject replay timeout by withholding ACK for > REPLAY_TIMEOUT cycles.
8. Verify DUT auto-replays.

**Pass Criteria**: Correct retry on NAK, correct replay on timeout.

### TC-06: `tc_cfg_access.v` — Configuration Read/Write

**Goal**: Verify configuration space read and write over PCIe.

**Steps**:
1. BFM sends `CfgRd0` for offset 0x000 (Vendor/Device ID).
2. Verify DUT returns `CplD` with correct Vendor/Device ID values.
3. BFM sends `CfgWr0` to Command register enabling Bus Master and Memory Space.
4. BFM reads back Command register; verify enable bits are set.
5. BFM writes all-1s to BAR0; reads back; verify size encoding.
6. BFM writes base address to BAR0.
7. Read `Device Capabilities` register; verify MPS field.

**Pass Criteria**: All read/write values match expected values.

### TC-07: `tc_mem_write.v` — Memory Write TLP

**Goal**: Verify posted memory write transactions.

**Steps**:
1. Link trained, FC initialized.
2. BFM enables DUT bus-master via Config Write.
3. BFM sends `MWr` TLP to DUT BAR0 address with 4-byte payload `0xDEADBEEF`.
4. Verify DUT asserts `app_mem_wr` with correct address, data, and byte-enables.
5. Send 128-byte burst write (32 DW); verify DUT streams all data to application.
6. Verify sequence number increments correctly.
7. Verify ACK DLLP sent by DUT.

**Pass Criteria**: All write data arrives correctly at application interface.

### TC-08: `tc_mem_read.v` — Memory Read + Completion

**Goal**: Verify non-posted memory read and CplD generation.

**Steps**:
1. BFM sends `MRd` TLP to DUT BAR0 address, Tag=5, Length=4 (16 bytes).
2. Verify DUT asserts `mem_rd_valid` with correct address, length, RID, Tag.
3. Testbench provides read data `0x12345678_9ABCDEF0_CAFEBABE_FEEDFACE`.
4. Verify DUT sends `CplD` TLP back to BFM with correct RID=BFM_RID, Tag=5.
5. BFM receives completion; verify data.
6. Test split completion: request 512 bytes; verify multiple CplD TLPs sized to RCB.

**Pass Criteria**: Data in completions matches read data, Tag matches.

### TC-09: `tc_msi.v` — MSI Interrupt

**Goal**: Verify MSI interrupt generation.

**Steps**:
1. BFM programs MSI capability (enable MSI, write MSI address and data).
2. Assert `app_int_req` with `app_int_vec = 0`.
3. Verify DUT sends `MWr` TLP to MSI address with MSI data.
4. Verify `app_int_ack` asserted after TLP sent.
5. Test with multiple vectors (int_vec = 3).

**Pass Criteria**: Correct MSI write TLP generated for each interrupt.

### TC-10: `tc_error_handling.v` — Error Injection

**Goal**: Verify error detection, reporting, and recovery.

**Steps**:
1. **Bad LCRC**: BFM sends TLP with corrupted LCRC; verify DUT sends NAK and does NOT forward TLP to TL.
2. **Bad sequence number**: BFM sends TLP with seq=5 when DUT expects seq=1; verify DUT sends NAK.
3. **Poisoned TLP (EP bit)**: BFM sends MWr with EP=1; verify DUT asserts error and sends ERR_NONFATAL message.
4. **Unsupported Request**: BFM sends IO Read to DUT (if IO space disabled); verify DUT sends UR completion.
5. **Completion Timeout**: DUT sends Config Read; BFM withholds completion for > TIMEOUT; verify DUT reports timeout.
6. **AER**: Read AER Uncorrectable Error Status register; verify correct bits set.

**Pass Criteria**: All error scenarios detected, correct error signaling and recovery.

---

## 10. Build and Simulation Flow

### 10.1 Prerequisites

```bash
sudo apt-get install iverilog gtkwave
```

### 10.2 Compiling with iverilog

Each test case is compiled with all required RTL files:

```bash
# Example: Compile TC-06 (Config Access)
iverilog -g2012 -Wall \
    -I rtl/phy -I rtl/dll -I rtl/tl -I rtl/top \
    -I tb/bfm \
    rtl/phy/pcie_8b10b_enc.v   \
    rtl/phy/pcie_8b10b_dec.v   \
    rtl/phy/pcie_scrambler.v   \
    rtl/phy/pcie_descrambler.v \
    rtl/phy/pcie_ltssm.v       \
    rtl/phy/pcie_phy_tx.v      \
    rtl/phy/pcie_phy_rx.v      \
    rtl/dll/pcie_crc32.v       \
    rtl/dll/pcie_crc16.v       \
    rtl/dll/pcie_replay_buffer.v \
    rtl/dll/pcie_dll_tx.v      \
    rtl/dll/pcie_dll_rx.v      \
    rtl/dll/pcie_flow_ctrl.v   \
    rtl/tl/pcie_tlp_encoder.v  \
    rtl/tl/pcie_tlp_decoder.v  \
    rtl/tl/pcie_cfg_space.v    \
    rtl/tl/pcie_completion_tracker.v \
    rtl/tl/pcie_tl_tx.v        \
    rtl/tl/pcie_tl_rx.v        \
    rtl/tl/pcie_msi.v          \
    rtl/top/pcie_endpoint.v    \
    tb/bfm/pcie_rc_bfm.v       \
    tb/bfm/pcie_link_model.v   \
    tb/bfm/pcie_monitor.v      \
    tb/tc/tc_cfg_access.v      \
    -o sim_cfg_access

# Run simulation
vvp sim_cfg_access

# View waveforms
gtkwave dump.vcd &
```

### 10.3 `scripts/run_tc.sh`

```bash
#!/bin/bash
# Usage: ./scripts/run_tc.sh <test_case_name>
# Example: ./scripts/run_tc.sh tc_cfg_access

TC=$1
if [ -z "$TC" ]; then
    echo "Usage: $0 <test_case>"
    exit 1
fi

RTL_FILES="rtl/phy/pcie_8b10b_enc.v rtl/phy/pcie_8b10b_dec.v \
           rtl/phy/pcie_scrambler.v rtl/phy/pcie_descrambler.v \
           rtl/phy/pcie_ltssm.v rtl/phy/pcie_phy_tx.v rtl/phy/pcie_phy_rx.v \
           rtl/dll/pcie_crc32.v rtl/dll/pcie_crc16.v \
           rtl/dll/pcie_replay_buffer.v rtl/dll/pcie_dll_tx.v rtl/dll/pcie_dll_rx.v \
           rtl/dll/pcie_flow_ctrl.v \
           rtl/tl/pcie_tlp_encoder.v rtl/tl/pcie_tlp_decoder.v \
           rtl/tl/pcie_cfg_space.v rtl/tl/pcie_completion_tracker.v \
           rtl/tl/pcie_tl_tx.v rtl/tl/pcie_tl_rx.v rtl/tl/pcie_msi.v \
           rtl/top/pcie_endpoint.v \
           tb/bfm/pcie_rc_bfm.v tb/bfm/pcie_link_model.v tb/bfm/pcie_monitor.v"

iverilog -g2012 -Wall \
    $RTL_FILES \
    tb/tc/${TC}.v \
    -o /tmp/sim_${TC} && \
vvp /tmp/sim_${TC} && \
echo "PASS: ${TC}" || \
echo "FAIL: ${TC}"
```

### 10.4 `scripts/run_all.sh`

```bash
#!/bin/bash
PASS=0
FAIL=0
for TC in tc_8b10b tc_scrambler tc_ltssm tc_ack_nak tc_flow_ctrl \
          tc_mem_write tc_mem_read tc_cfg_access tc_msi tc_error_handling; do
    ./scripts/run_tc.sh $TC
    if [ $? -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done
echo ""
echo "Results: PASS=$PASS  FAIL=$FAIL"
```

### 10.5 VCD Waveform Dumping

Each testbench includes:
```verilog
initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, tb_top);
    // ... stimulus ...
    $finish;
end
```

---

## 11. Verification Plan

### 11.1 Coverage Goals

| Feature                    | Test Case(s)                    | Coverage Target |
|----------------------------|---------------------------------|-----------------|
| 8b/10b all codes           | tc_8b10b                        | 100% (256 + K-codes) |
| Scrambler LFSR             | tc_scrambler                    | 100%            |
| LTSSM Detect→L0            | tc_ltssm                        | 100% state coverage |
| LTSSM L0→L0s→L0            | tc_ltssm                        | 100%            |
| ACK/NAK retry              | tc_ack_nak                      | 3 retries max   |
| Replay timeout             | tc_ack_nak                      | Covered         |
| FC Init (P/NP/Cpl)         | tc_flow_ctrl                    | All 3 classes   |
| FC backpressure            | tc_flow_ctrl                    | Covered         |
| Config Rd/Wr               | tc_cfg_access                   | Offset 0–0xFF   |
| BAR sizing                 | tc_cfg_access                   | BAR0–BAR1       |
| MWr 32-bit addr            | tc_mem_write                    | 100%            |
| MWr burst                  | tc_mem_write                    | MPS=128B        |
| MRd + CplD                 | tc_mem_read                     | 100%            |
| Split completion           | tc_mem_read                     | RCB boundary    |
| MSI single vector          | tc_msi                          | vec 0           |
| MSI multiple vectors       | tc_msi                          | vec 0–31        |
| LCRC error / NAK           | tc_error_handling               | Covered         |
| Poisoned TLP               | tc_error_handling               | Covered         |
| UR completion              | tc_error_handling               | Covered         |
| Completion timeout         | tc_error_handling               | Covered         |

### 11.2 Regression Strategy

All 10 test cases form the regression suite. Each test:
1. Runs the full link training sequence before exercising the feature.
2. Checks expected outputs using `$display` + automatic `$error` / `$fatal` on mismatch.
3. Ends with `$display("TEST PASSED")` or `$display("TEST FAILED")`.

### 11.3 Known Simulation Limitations

- No bit-accurate SerDes model (parallel simulation interface).
- No clock domain crossing (single clock domain).
- No temperature/voltage variation corner cases.
- Scrambling is tested behaviorally but not analog signal quality.

---

## 12. Implementation Milestones

| Milestone | Deliverables                                                    | Target       |
|-----------|-----------------------------------------------------------------|--------------|
| **M1**    | PHY layer: 8b/10b enc/dec + scrambler + basic LTSSM stub        | Week 1       |
| **M2**    | LTSSM full state machine + ordered set generation/detection     | Week 2       |
| **M3**    | DLL TX/RX: framing, CRC32/CRC16, sequence numbers              | Week 3       |
| **M4**    | Replay buffer + ACK/NAK protocol                               | Week 3       |
| **M5**    | Flow Control: InitFC / UpdateFC DLLP exchange                  | Week 4       |
| **M6**    | TL TX/RX: TLP encode/decode, Configuration Space               | Week 4–5     |
| **M7**    | Memory Read/Write, Completion Tracker, MSI                     | Week 5–6     |
| **M8**    | Top-level integration + RC BFM + link model                    | Week 6       |
| **M9**    | All 10 test cases passing                                      | Week 7       |
| **M10**   | Code review, cleanup, documentation                            | Week 8       |
