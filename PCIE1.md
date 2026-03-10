# PCI Express (PCIe) 1.0 Protocol — Comprehensive Study

## Table of Contents

1. [Introduction and Background](#1-introduction-and-background)
2. [Architecture Overview](#2-architecture-overview)
3. [Layered Architecture](#3-layered-architecture)
4. [Physical Layer](#4-physical-layer)
5. [Data Link Layer](#5-data-link-layer)
6. [Transaction Layer](#6-transaction-layer)
7. [Packet Formats](#7-packet-formats)
8. [Flow Control](#8-flow-control)
9. [Transaction Ordering](#9-transaction-ordering)
10. [Interrupts](#10-interrupts)
11. [Power Management](#11-power-management)
12. [Configuration Space](#12-configuration-space)
13. [Error Handling](#13-error-handling)
14. [PCIe Link Training and Initialization](#14-pcie-link-training-and-initialization)
15. [Timing and Performance](#15-timing-and-performance)
16. [Glossary](#16-glossary)
17. [References](#17-references)

---

## RTL Implementation Status (this repository)

The RTL in this repository now includes the PCIe 1.0 feature areas referenced throughout this document:
- Parameterized multi-lane PHY interfaces (`LINK_WIDTH`) for widths beyond ×1
- MSI, MSI-X vector signaling, and legacy INTx assert/deassert message generation
- LTSSM handling for L0/L0s/L1 low-power transitions
- AER extended capability header/status tracking with error-report message pulses

This remains a learning-oriented endpoint model, but these capability blocks are now present in RTL/testbench form.

---

## 1. Introduction and Background

### 1.1 History of PCI

The Peripheral Component Interconnect (PCI) bus was introduced by Intel in 1992. It replaced the earlier ISA, EISA, and MCA buses and offered a parallel, shared-bus topology operating at 33 MHz or 66 MHz with 32-bit or 64-bit data widths. PCI supported bus mastering DMA, plug-and-play configuration, and a rich ecosystem of devices.

The limitations of PCI — including the shared bus (limiting total bandwidth), signal integrity at higher frequencies, and scalability — led to the development of PCI-X (1998), which pushed frequency to 133 MHz and beyond. However, PCI-X still used the shared-bus topology and faced fundamental scalability walls.

### 1.2 Birth of PCIe

PCI Express (PCIe) was standardized by the PCI-SIG (Special Interest Group) in 2003. PCIe **version 1.0** specification was published in **July 2002** (with the final 1.0a revision in April 2003). PCIe replaced the shared parallel bus with a **point-to-point serial link** architecture, solving the scalability and signal-integrity problems of traditional PCI.

Key reasons for PCIe's success:
- **Point-to-point topology**: Dedicated lanes between each device and the root complex.
- **Serial differential signaling**: Eliminates the need for tight bus timing synchronization.
- **Scalable bandwidth**: Multiple lanes (×1, ×2, ×4, ×8, ×12, ×16, ×32) can be bonded together.
- **Software compatibility**: PCIe retains the PCI programming model (MMIO, Configuration Space), easing migration.

### 1.3 PCIe 1.0 Specifications at a Glance

| Parameter                   | Value                              |
|-----------------------------|------------------------------------|
| Specification Version       | 1.0 / 1.0a / 1.1                   |
| Release Year                | 2003                               |
| Line Rate per Lane          | 2.5 GT/s (Giga-transfers/second)   |
| Encoding                    | 8b/10b (20% overhead)              |
| Effective Bandwidth per Lane| 250 MB/s (unidirectional)          |
| Max Lanes                   | ×32                                |
| Max Bandwidth (×16)         | 4 GB/s (bidirectional = 8 GB/s)    |
| Voltage Swing (differential)| 0.8 V (nominal)                    |
| Connector Types             | x1, x4, x8, x16 edge connectors   |

---

## 2. Architecture Overview

### 2.1 Topology

PCIe uses a **switch-based, point-to-point** topology:

```
                        CPU/Host
                           |
                     Root Complex (RC)
                    /       |        \
                PCIe       PCIe      PCIe
               Switch    Endpoint   Endpoint
              /     \
          Endpoint  Endpoint
```

- **Root Complex (RC)**: The root of the PCIe hierarchy. Bridges the CPU/memory subsystem to the PCIe fabric. It contains one or more Root Ports.
- **Endpoint (EP)**: A PCIe device that acts as a requester or completer of transactions (e.g., a graphics card, NIC, NVMe SSD).
- **Switch**: Allows fan-out of PCIe links. Contains one Upstream Port and multiple Downstream Ports, with an internal virtual PCI-to-PCI bridge for each port.
- **PCI/PCIe Bridge**: Connects a legacy PCI/PCI-X bus segment to the PCIe fabric.

### 2.2 Link

A **PCIe link** is the full-duplex connection between two components. A link consists of one or more **lanes**. Each lane is a pair of unidirectional differential signal pairs:

```
Lane 0:  TXp/TXn  (transmit)
         RXp/RXn  (receive)
```

A ×4 link bundles four such lanes and aggregates bandwidth.

### 2.3 Bus, Device, Function (BDF) Addressing

PCIe maintains the PCI addressing model:
- **Bus Number** (8 bits): Up to 256 buses.
- **Device Number** (5 bits): Up to 32 devices per bus.
- **Function Number** (3 bits): Up to 8 functions per device.

This gives a 16-bit Requester ID (RID) = `[Bus:8][Device:5][Function:3]`.

---

## 3. Layered Architecture

PCIe defines a **three-layer architecture** analogous to a network protocol stack:

```
+-----------------------------------+
|         Transaction Layer         |  <- Software interface (TLP generation/consumption)
+-----------------------------------+
|           Data Link Layer         |  <- Reliable delivery (DLLP, ACK/NAK)
+-----------------------------------+
|          Physical Layer           |  <- Bit transmission (8b/10b, differential signaling)
+-----------------------------------+
```

Each layer has well-defined services and communicates with adjacent layers via defined interfaces.

---

## 4. Physical Layer

### 4.1 Differential Signaling

PCIe uses **Low-Voltage Differential Signaling (LVDS)**. A signal is transmitted as the difference voltage between two complementary wires (D+ and D-). This provides:
- High common-mode noise rejection.
- Lower power compared to single-ended signaling.
- Supports DC coupling for AC coupling-free designs.

Nominal differential voltage swing: **800 mV peak-to-peak** (400 mV single-ended).

### 4.2 8b/10b Encoding

PCIe 1.0 uses **8b/10b encoding** on every lane. Each 8-bit data byte is encoded as a 10-bit symbol, providing:

1. **DC balance**: Ensures equal numbers of 0s and 1s over time so AC-coupled receivers can track the signal.
2. **Clock/data recovery (CDR)**: Frequent transitions allow the receiver's CDR circuit to lock onto the transmitter clock.
3. **Special symbols**: Certain 10-bit codes are reserved as **K-codes** (control symbols) rather than data.

Overhead: 2 bits per byte = **20% bandwidth overhead** → effective data rate = 2.5 Gb/s × 0.8 = **2.0 Gb/s = 250 MB/s per lane per direction**.

#### Key 8b/10b Symbols in PCIe

| Symbol | Hex  | Meaning                              |
|--------|------|--------------------------------------|
| K28.5  | 0xBC | Comma (used for lane alignment)      |
| K27.7  | 0xFB | STP — Start of TLP                   |
| K28.2  | 0x5C | SDP — Start of DLLP                  |
| K29.7  | 0xFD | END — End of Packet                  |
| K30.7  | 0xFE | EDB — End-of-Packet Bad (TLP error)  |
| K23.7  | 0xF7 | PAD — Lane idle                      |

### 4.3 Scrambling

PCIe 1.0 optionally scrambles the data using a **Linear Feedback Shift Register (LFSR)** with polynomial `x^16 + x^5 + x^4 + x^3 + 1`. Scrambling:
- Reduces EMI by spreading the power spectrum.
- Is applied after 8b/10b encoding at the byte level.
- Is reset at the start of each TLP/DLLP.

### 4.4 Link Training and Status State Machine (LTSSM)

The LTSSM manages the PCIe link lifecycle. It is implemented in the Physical Layer and has the following major states:

```
Detect → Polling → Configuration → L0 (operational) → Recovery → ...
                                    ↕
                               L0s (low power)
                                    ↕
                               L1 (low power)
                                    ↕
                               L2/L3 (lowest power)
```

#### LTSSM States

| State         | Description                                                              |
|---------------|--------------------------------------------------------------------------|
| **Detect**    | Detect whether a receiver is present using electrical idle detection.    |
| **Polling**   | Transmit TS1/TS2 ordered sets for bit-lock and symbol-lock.              |
| **Config**    | Lane/link-width negotiation; transmit/receive TS2s to confirm config.    |
| **L0**        | Normal operating state. Data can be transferred.                         |
| **Recovery**  | Re-establish bit/symbol lock after errors or speed change.               |
| **L0s**       | Low-power state; fast exit (~1 µs). Entered after IDLE_TO_L0s timer.    |
| **L1**        | Deeper low-power state; slower exit (~20 µs). Requires handshake.       |
| **L2**        | Very low power; link powered down. Used for system suspend.              |
| **Disabled**  | Link disabled by software.                                               |
| **Hot Reset** | PCIe reset propagated across the link.                                   |
| **Loopback**  | Test/debug mode; master re-receives its own transmitted data.            |

#### Training Sets (TS1 / TS2)

Training Sets are ordered sets of 16 symbols transmitted during link training:

| Field           | Bits | Description                                  |
|-----------------|------|----------------------------------------------|
| COM (K28.5)     | 10   | Start of ordered set                         |
| Link #          | 10   | Link number (FFh = PAD)                      |
| Lane #          | 10   | Lane number (FFh = PAD)                      |
| N_FTS           | 10   | Number of FTS ordered sets needed for L0s    |
| Data Rate       | 10   | Supported data rate identifiers              |
| Training Ctrl   | 10   | Control bits (Reset, Disable, Loopback, etc) |
| TS ID           | 6×10 | 6 symbols identifying TS1 (D10.2) or TS2 (D5.2) |

### 4.5 Fast Training Sequences (FTS)

FTS ordered sets are used during L0s exit to re-establish bit and symbol lock quickly. The number of FTS needed is negotiated during link training (N_FTS field in TS1/TS2).

### 4.6 Electrical Idle

A transmitter signals **Electrical Idle** (EI) by driving both D+ and D- to a common voltage (near zero differential). This is used to indicate no data is being transmitted, and is also used in L0s, L1, and L2 power states.

### 4.7 Lane Polarity Inversion

PCIe 1.0 supports **polarity inversion** on a per-lane basis. If the board routes D+ to D- and vice versa, the receiver can detect and correct this via the TS1/TS2 training process.

### 4.8 Lane Reversal

PCIe supports **lane reversal**: a ×4 device can be connected with Lane 0 of the transmitter connected to Lane 3 of the receiver (and vice versa), and the Physical Layer will automatically reverse the lane ordering.

---

## 5. Data Link Layer

The Data Link Layer (DLL) sits between the Physical Layer and Transaction Layer. Its primary responsibilities are:

- **Reliable delivery** of Transaction Layer Packets (TLPs) using an **ACK/NAK** retry mechanism.
- Generation and consumption of **Data Link Layer Packets (DLLPs)** for flow control updates and power management.
- **Sequence numbering** of TLPs.
- **CRC protection** of TLPs (LCRC) and DLLPs (CRC16).

### 5.1 TLP Sequence Numbers

Every TLP transmitted is assigned a 12-bit **sequence number** (0–4095, wrapping). The sequence number is prepended to the TLP before transmission and used for ACK/NAK processing.

### 5.2 ACK/NAK Protocol

```
Transmitter                        Receiver
    |                                  |
    |----TLP[seq=N]------------------→|
    |                                  | Checks LCRC, sequence order
    |←--ACK[AckNak_SeqNum=N]----------|  (positive acknowledgment)
    |                                  |
    |----TLP[seq=N+1]---------------→ |
    |                                  | CRC error detected
    |←--NAK[AckNak_SeqNum=N]----------|  (negative acknowledgment)
    |                                  |
    | Retransmits from N+1             |
    |----TLP[seq=N+1]---------------→ |
```

- **ACK**: Receiver sends ACK DLLP when TLP is received correctly. The `AckNak_SeqNum` field in the ACK acknowledges all TLPs up to and including the specified sequence number.
- **NAK**: Receiver sends NAK DLLP when a TLP is received with a CRC error or out of sequence. Transmitter replays the Replay Buffer from `AckNak_SeqNum + 1`.
- **Replay Buffer**: The transmitter maintains a **Replay Buffer** of all unacknowledged TLPs. On NAK or timeout, the buffer is replayed.
- **Replay Timeout**: If no ACK/NAK is received within a timeout period, the transmitter initiates replay.
- **Replay_Num**: Counts replay attempts (max 4 retries before declaring a link error).

### 5.3 LCRC (Link CRC)

LCRC is a 32-bit CRC appended to every TLP. It covers the TLP header and data payload.

- **Polynomial**: `x^32 + x^26 + x^23 + x^22 + x^16 + x^12 + x^11 + x^10 + x^8 + x^7 + x^5 + x^4 + x^2 + x + 1` (same as Ethernet CRC-32).
- Computed over the sequence number and all TLP bytes.
- Initial value: all 1s; final XOR: all 1s.

### 5.4 DLLP Format

DLLPs are 8 bytes total:

```
Byte 0: DLLP Type
Bytes 1–3: Type-specific fields
Bytes 4–5: CRC-16
```

DLLPs are **never retried** (they are point-to-point and if lost, a timeout recovery handles it).

#### DLLP Types

| Type Code | Name                         | Function                                     |
|-----------|------------------------------|----------------------------------------------|
| 0x00      | ACK                          | Positive acknowledgment                      |
| 0x10      | NAK                          | Negative acknowledgment                      |
| 0x20      | PM_Enter_L1                  | Initiate L1 power state entry                |
| 0x21      | PM_Enter_L23                 | Initiate L2/L3 power state entry             |
| 0x22      | PM_Active_State_Request_L1   | Active state L1 PM request                  |
| 0x23      | PM_Request_Ack               | Power management request acknowledgment      |
| 0x30      | Vendor-Specific              | Vendor-defined DLLP                          |
| 0x40–0x5F | InitFC1                      | Initial Flow Control credit type 1           |
| 0x60–0x7F | InitFC2                      | Initial Flow Control credit type 2           |
| 0x80–0x9F | UpdateFC                     | Flow Control update                          |

### 5.5 Flow Control (FC) at the Data Link Layer

Flow control credits are exchanged via DLLPs. The DLL manages FC on behalf of the Transaction Layer (see Section 8 for full details).

---

## 6. Transaction Layer

The Transaction Layer (TL) is the highest layer in the PCIe protocol stack. It:

- **Generates TLPs** (Transaction Layer Packets) from CPU memory reads/writes and configuration accesses.
- **Consumes TLPs** and delivers completions/data to software.
- Manages **Virtual Channels (VCs)** and **Traffic Classes (TCs)**.
- Enforces **transaction ordering rules**.
- Manages **flow control credits**.

### 6.1 Transaction Types

PCIe 1.0 supports the following transaction types:

#### Memory Transactions
| Transaction               | Direction       | Description                                    |
|---------------------------|-----------------|------------------------------------------------|
| Memory Read (MRd)         | Request         | Read data from memory-mapped address space     |
| Memory Read Lock (MRdLk)  | Request         | Locked memory read (legacy PCI lock support)   |
| Memory Write (MWr)        | Posted Request  | Write data to memory-mapped address space      |

#### I/O Transactions (Legacy PCI Compatibility)
| Transaction   | Direction  | Description                          |
|---------------|------------|--------------------------------------|
| IO Read (IORd)  | Request  | Read from I/O address space          |
| IO Write (IOWr) | Request  | Write to I/O address space           |

#### Configuration Transactions
| Transaction     | Direction  | Description                                         |
|-----------------|------------|-----------------------------------------------------|
| CfgRd0 / CfgRd1 | Request  | Configuration Read (Type 0: local, Type 1: routed)  |
| CfgWr0 / CfgWr1 | Request  | Configuration Write                                 |

#### Message Transactions
| Transaction     | Direction       | Description                                         |
|-----------------|-----------------|-----------------------------------------------------|
| Msg / MsgD      | Posted Request  | Message (without/with data payload)                 |

#### Completion Transactions
| Transaction       | Direction    | Description                                             |
|-------------------|--------------|---------------------------------------------------------|
| Cpl               | Completion   | Completion without data (for I/O and Config writes)     |
| CplD              | Completion   | Completion with data (for Memory, I/O, Config reads)    |
| CplLk / CplDLk    | Completion   | Completion for locked transactions                      |

### 6.2 Posted vs. Non-Posted Transactions

- **Posted Transactions**: Do not require a completion. Sent and forgotten. Examples: Memory Writes, Messages.
- **Non-Posted Transactions**: Require a completion TLP in response. Examples: Memory Reads, I/O Reads/Writes, Configuration Reads/Writes.

### 6.3 Requester ID and Completer ID

Every TLP carries:
- **Requester ID (RID)**: Identifies the device that originated the request (Bus:Device:Function).
- **Completer ID (CID)**: Identifies the device that sent the completion. Completions route back to the RID.

### 6.4 Tag

Non-posted requests include a **Tag** field (8 bits in PCIe 1.0: 5-bit base, extended to 8 bits with Extended Tag capability). The Tag uniquely identifies an outstanding request and is used to match completions to requests.

### 6.5 Address Types

PCIe supports four address spaces:
- **Memory Space** (32-bit or 64-bit addresses)
- **I/O Space** (32-bit addresses, legacy)
- **Configuration Space** (PCIe Extended Config = 4096 bytes per function)
- **Message Space** (in-band signaling, no address required)

---

## 7. Packet Formats

### 7.1 General TLP Structure

```
+----------------+----------------+
|  Sequence Number (12b) | R (4b)|  ← DLL header (prepended by DLL)
+-----------------------------------+
|        TLP Header (3 or 4 DW)    |
+-----------------------------------+
|        Data Payload (0–1024 DW)  |  ← Optional
+-----------------------------------+
|           LCRC (32-bit)          |  ← DLL trailer (appended by DLL)
+-----------------------------------+
```

DW = Double Word = 4 bytes.

### 7.2 TLP Header — Common Fields (DW0)

```
Bits [31:29] — Fmt (Format): 
    000 = 3-DW header, no data
    001 = 4-DW header, no data
    010 = 3-DW header, with data
    011 = 4-DW header, with data

Bits [28:24] — Type:
    00000 = MRd (Memory Read)
    00001 = MRdLk (Memory Read Lock)
    01000 = MWr (Memory Write)
    00010 = IORd
    00011 = IOWr
    00100 = CfgRd0
    00101 = CfgWr0
    00110 = CfgRd1
    00111 = CfgWr1
    01010 = Cpl (Completion)
    01011 = CplD (Completion with Data)
    01100 = CplLk
    01101 = CplDLk
    10xxx = Msg/MsgD (various subtypes)

Bit  [23]   — T9: Traffic Class bit 2 (extended)
Bit  [22]   — R (reserved)
Bits [21:20]— Attr[1:0]: Attributes (Relaxed Ordering [bit1], No Snoop [bit0])
Bit  [19]   — T8: Traffic Class bit 1 (extended) 
Bit  [18]   — R (reserved)
Bit  [17]   — EP: Poisoned Data (Error in data payload)
Bit  [16]   — TD: TLP Digest present (ECRC appended)
Bits [15:12]— R (reserved)
Bits [11:10]— AT: Address Type (00=default, 01=translation request, 10=translated)
Bits  [9:0] — Length: Payload length in DW (0 = 1024 DW)
```

### 7.3 Memory Read Request (MRd) — 3-DW Header (32-bit address)

```
DW0: Fmt=000, Type=00000, TC, Attr, Length
DW1: [31:16] Requester ID | [15:8] Tag | [7:4] LastDW BE | [3:0] FirstDW BE
DW2: [31:2] Address[31:2] | [1:0] R (reserved, must be 0)
```

### 7.4 Memory Read Request (MRd) — 4-DW Header (64-bit address)

```
DW0: Fmt=001, Type=00000, TC, Attr, Length
DW1: [31:16] Requester ID | [15:8] Tag | [7:4] LastDW BE | [3:0] FirstDW BE
DW2: [31:0] Address[63:32]
DW3: [31:2] Address[31:2] | [1:0] R
```

### 7.5 Memory Write Request (MWr) — 3-DW Header

```
DW0: Fmt=010, Type=01000, TC, Attr, Length
DW1: [31:16] Requester ID | [15:8] Tag | [7:4] LastDW BE | [3:0] FirstDW BE
DW2: [31:2] Address[31:2] | [1:0] R
Data Payload: Length × 4 bytes
```

### 7.6 Completion with Data (CplD) — 3-DW Header

```
DW0: Fmt=010, Type=01011, TC, Attr, Length (= data length in DW)
DW1: [31:16] Completer ID | [15:13] Completion Status | [12] BCM | [11:0] Byte Count
DW2: [31:16] Requester ID | [15:8] Tag | [7:0] Lower Address
Data Payload: up to 4096 bytes, but split into completion packets ≤ RCB
```

**Completion Status codes:**
| Code | Name                    | Description                                      |
|------|-------------------------|--------------------------------------------------|
| 000  | SC (Successful Completion) | Transaction completed successfully           |
| 001  | UR (Unsupported Request)   | Target does not support the request          |
| 010  | CRS (Configuration Retry Status) | Config access retry          |
| 100  | CA (Completer Abort)       | Target is aborting the transaction           |

### 7.7 Configuration Transaction

Type 0 configuration access targets a function on the local bus; Type 1 is routed by switches to a downstream bus.

```
DW0: Fmt=000, Type=00100(CfgRd0)/00101(CfgWr0), TC, Attr, Length=1
DW1: [31:16] Requester ID | [15:8] Tag | [7:4] LastDW BE | [3:0] FirstDW BE
DW2: [31:16] Device:Function (Bus is embedded in routing) | [15:8] Ext Reg # | [7:2] Reg # | [1:0] R
```

### 7.8 Message TLP

Messages replace the sideband signals of PCI (INTA, PME, hot-plug events, etc.).

```
DW0: Fmt=001/011, Type=10rrr, TC, Attr, Length (0 if no data)
DW1: [31:16] Requester ID | [15:8] Tag | [7:0] Message Code
DW2–DW3: Message-specific address or routing information
```

**Message Codes:**
| Code  | Name                 | Description                             |
|-------|----------------------|-----------------------------------------|
| 0x00  | Unlock               | Legacy PCI bus unlock                   |
| 0x10  | Attention Indicator  | Attention button pressed                |
| 0x11  | Attention Indicator  | Power Indicator (hot-plug)              |
| 0x14  | Attention Button     | Hot-plug attention button               |
| 0x20  | PME_Turn_Off         | PM event: turn off                      |
| 0x21  | PM_PME               | PM event                                |
| 0x24  | PME_TO_Ack           | PM event turn-off acknowledge           |
| 0x30  | ERR_COR              | Correctable error message               |
| 0x31  | ERR_NONFATAL         | Non-fatal uncorrectable error message   |
| 0x33  | ERR_FATAL            | Fatal uncorrectable error message       |
| 0x7E  | Vendor_Defined 0     | Vendor-defined message (no data)        |
| 0x7F  | Vendor_Defined 1     | Vendor-defined message (with data)      |

### 7.9 ECRC (End-to-End CRC)

If the TD bit is set in the TLP header, an optional **ECRC** (32-bit CRC) is appended after the data payload. ECRC protects against data corruption through switches and is verified only by the final destination.

- Uses the same CRC-32 polynomial as LCRC.
- Computed over the entire TLP header + data (with the EP bit treated as 1).

---

## 8. Flow Control

PCIe flow control prevents receiver buffer overflow by ensuring a transmitter never sends more data than the receiver can accept.

### 8.1 Flow Control Units (FCUs)

Flow control credit granularity:
- **Header Credits (H)**: 1 credit per TLP header (5 DW = 20 bytes reserved per header credit).
- **Data Credits (D)**: 1 credit per 4 DW (16 bytes) of payload.

### 8.2 Flow Control Classes

Flow control is maintained per **Virtual Channel (VC)** and per **TLP class**:

| FC Class | TLP Types                        |
|----------|----------------------------------|
| **P**    | Posted Requests (MWr, Msg/MsgD)  |
| **NP**   | Non-Posted Requests (MRd, IORd, IOWr, CfgRd/Wr) |
| **Cpl**  | Completions (Cpl, CplD)          |

### 8.3 Flow Control Initialization

At link startup (before L0), the receiver advertises its buffer capacity:

1. **InitFC1 DLLPs**: Receiver sends `InitFC1` DLLPs for each credit class and VC, advertising its header and data credit counts.
2. **InitFC2 DLLPs**: Receiver sends `InitFC2` (confirmation) after receiving InitFC1 from the remote side.
3. Once both sides have sent InitFC2, flow control is initialized and TLP transmission may begin.

**Infinite credits**: A credit value of 0 in InitFC1/InitFC2 indicates infinite credits (receiver never runs out of space — typically used for completions in the Root Complex or for posted requests in endpoints that do not need to backpressure).

### 8.4 Credit Update (UpdateFC DLLPs)

As the receiver consumes TLPs from its buffer, it sends **UpdateFC DLLPs** to return credits to the transmitter. The transmitter maintains credit counters per FC class:

```
Transmitter may send a TLP if:
  FCCL (FC Credit Limit) ≥ FCON (FC Credits Needed for this TLP)
  
  where: FCCL = last received FC credit value
         FCON = header credits needed + data credits needed
```

### 8.5 UpdateFC DLLP Format

```
Bits [7:0]:   0x80–0x9F = UpdateFC (bits [5:4] encode VC; bits [3:0] part of type)
Bits [11:8]:  FC credit type (P/NP/Cpl) and header/data flag
Bits [19:12]: Header credits (HdrFC[7:0]) or Data credits [MSB]
Bits [31:20]: Data credits (DatFC[11:0])
Bits [47:32]: CRC-16
```

---

## 9. Transaction Ordering

PCIe defines a **Transaction Ordering Model** based on PCI ordering rules, extended for the point-to-point topology:

### 9.1 Producer-Consumer Model

The PCIe ordering model follows the **producer-consumer** pattern:
1. Producer writes data to a shared buffer (memory write — Posted).
2. Producer sends a flag/doorbell (another Posted write).
3. Consumer reads the flag (Non-Posted read) — must see the data from step 1.

PCIe guarantees that **a Posted Write from the same source is observed at the destination before a later Non-Posted transaction from the same source completes**.

### 9.2 Ordering Rules Table

| Row Transaction →       | Memory Write (P) | Read Request (NP) | Read Completion (Cpl) |
|-------------------------|:----------------:|:-----------------:|:---------------------:|
| **↓ Must Pass?**        |                  |                   |                       |
| Memory Write (P)        | No (may pass)    | Yes               | Yes                   |
| Read Request (NP)       | No               | No (may pass)     | Yes                   |
| Read Completion (Cpl)   | No               | No                | No (may pass)         |

"May pass" means the transaction can be reordered ahead of the listed type. "Yes" means it must not pass (strong ordering required).

The **Relaxed Ordering (RO)** attribute in the TLP header allows a transaction to relax some of these rules for performance optimization, if both ends support it.

### 9.3 No-Snoop Attribute

The **No Snoop (NS)** attribute tells the system that the data does not need to be snooped by the processor cache, allowing for a more efficient path in the chipset/memory controller.

---

## 10. Interrupts

PCIe replaces PCI sideband interrupt lines (INTA#–INTD#) with in-band messaging.

### 10.1 INTx Emulation (Legacy Interrupts)

For backward compatibility, PCIe supports virtual INTx signals using **Assert_INTx** and **Deassert_INTx** message TLPs (Message Codes 0x04–0x07 and 0x24–0x27).

- Legacy PCI INTx lines are mapped to INTA (if single-function) or rotated per function.
- Only endpoints can generate INTx messages; Root Complex translates them to system interrupts.

### 10.2 MSI (Message Signaled Interrupts)

MSI was introduced with PCI 2.2 and is fully supported in PCIe:
- Device performs a **Memory Write** to a special address/data pair programmed by the OS in the MSI capability structure.
- Up to 32 interrupt vectors per function (encoded in the message data field).
- No sideband wiring required.

### 10.3 MSI-X

MSI-X is a more scalable extension:
- Up to **2048 interrupt vectors** per function.
- Each vector has its own **Message Address** and **Message Data** stored in a **MSI-X Table** (in BAR space).
- A **Pending Bit Array (PBA)** tracks which interrupts are pending.
- Vectors can be independently masked.

---

## 11. Power Management

PCIe 1.0 supports both **PCIe Active State Power Management (ASPM)** and **PCI PM (PME)**.

### 11.1 Link Power States

| State | Name                      | Exit Latency    | Description                                             |
|-------|---------------------------|-----------------|----------------------------------------------------------|
| **L0**  | Fully Active              | N/A             | Normal operating state                                  |
| **L0s** | Active State Low Power    | < 1 µs          | One direction can be in low power; uses FTS to exit     |
| **L1**  | Active State Deep Power   | 2–4 µs          | Both directions in electrical idle; requires DLLP handshake |
| **L2**  | Auxiliary Power           | 10–100+ ms      | Main power removed; AUX power maintained for wake       |
| **L3**  | Off                       | Cold start      | No power; link must fully retrain                       |

### 11.2 L0s Entry/Exit

- Entered automatically after ASPM L0s idle timer expires.
- Exit: Receiver detects FTS symbols and transitions to L0.

### 11.3 L1 Entry/Exit

1. Downstream component sends `PM_Active_State_Request_L1` DLLP.
2. Upstream component responds with `PM_Request_Ack` DLLP.
3. Both sides enter electrical idle and LTSSM transitions to L1.
4. Exit triggered by either side sending FTS → Recovery → L0.

### 11.4 Device Power States (D-states)

Defined by the PCI PM specification:
| State | Description                                    |
|-------|------------------------------------------------|
| D0    | Fully powered and operational                  |
| D1    | Intermediate low power (device-class specific) |
| D2    | Intermediate low power (device-class specific) |
| D3hot | Device context lost; power still present       |
| D3cold | All power removed                             |

---

## 12. Configuration Space

### 12.1 PCI-Compatible Configuration Space (256 bytes)

Every PCIe function has 256 bytes of **PCI-compatible configuration space** at offsets 0x000–0x0FF:

```
Offset  Register
0x00    Vendor ID / Device ID
0x04    Command / Status
0x08    Revision ID / Class Code
0x0C    Cache Line Size / Latency Timer / Header Type / BIST
0x10–0x27  BAR0–BAR5 (Base Address Registers)
0x28    Cardbus CIS Pointer
0x2C    Subsystem Vendor ID / Subsystem ID
0x30    Expansion ROM Base Address
0x34    Capabilities Pointer
0x38    Reserved
0x3C    Interrupt Line / Interrupt Pin / Min_Grant / Max_Latency
0x40–0xFF  Device-specific / Capabilities
```

### 12.2 PCIe Extended Configuration Space (4096 bytes)

PCIe extends configuration space to **4096 bytes** (offsets 0x000–0xFFF). The region 0x100–0xFFF contains **PCIe Extended Capabilities**:

Each extended capability starts with a 32-bit header:
```
Bits [31:20]: Next Capability Offset
Bits [19:16]: Capability Version
Bits [15:0]:  Extended Capability ID
```

**Key Extended Capabilities in PCIe 1.0:**

| Cap ID | Name                           |
|--------|--------------------------------|
| 0x001  | Advanced Error Reporting (AER) |
| 0x002  | Virtual Channel (VC)           |
| 0x003  | Device Serial Number           |
| 0x004  | Power Budgeting                |

### 12.3 PCIe Capability Structure (PCI Capability ID = 0x10)

Located in the PCI-compatible space (via Capabilities Pointer), this is the primary PCIe capability:

```
Offset +0x00: Capability ID (0x10) / Next Ptr / PCIe Capability Register
Offset +0x04: Device Capabilities
Offset +0x08: Device Control / Device Status
Offset +0x0C: Link Capabilities
Offset +0x10: Link Control / Link Status
Offset +0x14: Slot Capabilities (if present)
Offset +0x18: Slot Control / Slot Status (if present)
Offset +0x1C: Root Control / Root Capabilities (if Root Port)
Offset +0x20: Root Status (if Root Port)
```

### 12.4 BAR (Base Address Register) Decoding

BARs define the address space windows the device uses:
- **Bit 0 = 0**: Memory BAR. Bits [2:1] encode size type (00 = 32-bit, 10 = 64-bit).
- **Bit 0 = 1**: I/O BAR.
- Size determined by writing all 1s and reading back (cleared lower bits indicate required alignment).

---

## 13. Error Handling

PCIe 1.0 defines a comprehensive error handling architecture with three error severity levels:

### 13.1 Error Categories

| Severity     | Description                                                                    |
|--------------|--------------------------------------------------------------------------------|
| **Correctable** | Detected and corrected internally; no data loss. Logged in AER.            |
| **Non-Fatal Uncorrectable** | Detected but not corrected; transaction affected but link intact. |
| **Fatal Uncorrectable** | Unrecoverable error; requires link reset.                          |

### 13.2 Correctable Errors

- Receiver Error (bad 8b/10b symbol)
- Bad TLP (LCRC error, framing error)
- Bad DLLP (CRC-16 error)
- Replay Num Rollover (replay counter overflow)
- Replay Timer Timeout

### 13.3 Uncorrectable Errors

| Error                         | Default Severity |
|-------------------------------|------------------|
| Data Link Protocol Error       | Fatal            |
| Surprise Down Error            | Fatal            |
| Poisoned TLP (EP bit set)      | Non-Fatal        |
| Flow Control Protocol Error    | Fatal            |
| Completion Timeout             | Non-Fatal        |
| Completer Abort                | Non-Fatal        |
| Unexpected Completion          | Non-Fatal        |
| Receiver Overflow              | Fatal            |
| Malformed TLP                  | Fatal            |
| ECRC Error                     | Non-Fatal        |
| Unsupported Request            | Non-Fatal        |

### 13.4 Advanced Error Reporting (AER)

The AER Extended Capability (Cap ID 0x001) provides:
- **Uncorrectable Error Status/Mask/Severity registers**
- **Correctable Error Status/Mask registers**
- **Root Error Command/Status registers** (Root Complex only)
- **Header Log** (first 4 DW of the offending TLP header)

### 13.5 Error Signaling

Errors are reported via Message TLPs to the Root Complex:
- `ERR_COR` for correctable errors
- `ERR_NONFATAL` for non-fatal uncorrectable errors
- `ERR_FATAL` for fatal uncorrectable errors

---

## 14. PCIe Link Training and Initialization

### 14.1 Power-On Sequence

1. **Power stabilizes** → PERST# (fundamental reset) is de-asserted.
2. **Detect**: Transmitter checks for receiver presence (impedance detection).
3. **Polling**: Bit lock and symbol lock established using K28.5 comma characters and TS1 ordered sets.
4. **Configuration**: 
   - Link width negotiation (number of active lanes).
   - Lane-to-lane de-skew.
   - Polarity and reversal correction.
5. **L0**: Link enters normal operating state.
6. **DLL Initialization**: Flow control credits exchanged via InitFC1/InitFC2 DLLPs.
7. **Software Access**: Root Complex enumerates connected devices via Configuration Read/Write transactions.

### 14.2 Enumeration

PCIe enumeration is identical to PCI:
1. Root Complex starts at Bus 0, Device 0, Function 0.
2. BIOS/OS reads Vendor ID to check for device presence.
3. For bridges/switches, assigns secondary and subordinate bus numbers.
4. Assigns memory, I/O BAR windows.
5. Enables devices via Command register.

### 14.3 Link Width and Speed Negotiation

- Width is negotiated during Config state of LTSSM by counting how many lanes complete training.
- PCIe 1.0 supports only **2.5 GT/s** (no speed change negotiation needed for 1.0-only devices).

---

## 15. Timing and Performance

### 15.1 Bandwidth Calculations

For a PCIe 1.0 ×N link:

| Width | Raw Rate        | After 8b/10b  | Bidirectional |
|-------|-----------------|---------------|---------------|
| ×1    | 2.5 Gb/s        | 250 MB/s      | 500 MB/s      |
| ×2    | 5 Gb/s          | 500 MB/s      | 1 GB/s        |
| ×4    | 10 Gb/s         | 1 GB/s        | 2 GB/s        |
| ×8    | 20 Gb/s         | 2 GB/s        | 4 GB/s        |
| ×16   | 40 Gb/s         | 4 GB/s        | 8 GB/s        |

### 15.2 Latency Contributors

| Component                      | Approximate Latency    |
|--------------------------------|------------------------|
| Serialization (×1, 128 bytes)  | ~400 ns                |
| Propagation delay (1m trace)   | ~5 ns                  |
| Switch traversal               | ~100–200 ns            |
| Memory access (DRAM)           | ~50–100 ns             |
| Total end-to-end (simple)      | ~1–2 µs                |

### 15.3 Maximum Payload Size (MPS)

MPS defines the maximum data payload in a single TLP. Supported values: 128, 256, 512, 1024, 2048, 4096 bytes.

- The actual MPS is the minimum of all MPS values in the path.
- PCIe 1.0 baseline: **128 bytes MPS**.

### 15.4 Maximum Read Request Size (MRRS)

MRRS defines the maximum size the requester may request in a single read request. Must be ≥ MPS.

### 15.5 Read Completion Boundary (RCB)

The Read Completion Boundary (RCB) is 64 bytes for Root Complex and 128 bytes otherwise. Completions should not cross RCB boundaries, allowing the RCB-aligned sections to be used independently.

---

## 16. Glossary

| Term     | Definition                                                        |
|----------|-------------------------------------------------------------------|
| ACK      | Acknowledgment DLLP — positive acknowledgment of TLP receipt     |
| ASPM     | Active State Power Management                                     |
| AER      | Advanced Error Reporting (PCIe Extended Capability)              |
| BAR      | Base Address Register                                             |
| BDF      | Bus:Device:Function — PCIe addressing tuple                       |
| CDR      | Clock and Data Recovery circuit                                   |
| Cpl/CplD | Completion / Completion with Data TLP                            |
| CRC      | Cyclic Redundancy Check                                           |
| DLLP     | Data Link Layer Packet                                            |
| ECRC     | End-to-End CRC (TLP Digest)                                      |
| EI       | Electrical Idle                                                   |
| EP       | Endpoint (PCIe device) / Poisoned Data bit in TLP                |
| FC       | Flow Control                                                      |
| FCU      | Flow Control Unit                                                 |
| FTS      | Fast Training Sequence                                            |
| GT/s     | Giga-transfers per second                                         |
| LCRC     | Link CRC (32-bit CRC on TLP, added by DLL)                       |
| LFSR     | Linear Feedback Shift Register                                    |
| LTSSM    | Link Training and Status State Machine                            |
| MSI      | Message Signaled Interrupt                                        |
| MSI-X    | Extended Message Signaled Interrupt                               |
| MPS      | Maximum Payload Size                                              |
| MRRS     | Maximum Read Request Size                                         |
| NAK      | Negative Acknowledgment DLLP                                      |
| NP       | Non-Posted transaction class                                      |
| P        | Posted transaction class                                          |
| PCI-SIG  | PCI Special Interest Group                                        |
| PERST#   | PCIe Fundamental Reset (active-low)                              |
| RC       | Root Complex                                                      |
| RCB      | Read Completion Boundary                                          |
| RID      | Requester ID (Bus:Device:Function)                                |
| TC       | Traffic Class                                                     |
| TL       | Transaction Layer                                                 |
| TLP      | Transaction Layer Packet                                          |
| TS1/TS2  | Training Set 1/2 (ordered sets used during link training)         |
| VC       | Virtual Channel                                                   |

---

## 17. References

1. PCI Express Base Specification Revision 1.0, PCI-SIG, July 22, 2002.
2. PCI Express Base Specification Revision 1.0a, PCI-SIG, April 15, 2003.
3. PCI Express Base Specification Revision 1.1, PCI-SIG, March 28, 2005.
4. PCI Local Bus Specification Revision 3.0, PCI-SIG, 2002.
5. *PCI Express System Architecture*, Ravi Budruk, Don Anderson, Tom Shanley; Mindshare Press / Addison-Wesley, 2003. ISBN 0-321-15630-7.
6. *PCIe Technology Overview*, Xilinx/AMD Application Note XAPP715.
7. Intel Platform Innovation Framework for EFI — PCIe Support.
8. MindShare PCI Express Deep Dive technical seminars.
