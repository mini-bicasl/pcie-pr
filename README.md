# PCIe 1.0 Verilog Implementation

A comprehensive study, implementation plan, and Verilog RTL project for a
**PCI Express 1.0 ×1 Endpoint**, verified with **Icarus Verilog (iverilog)**.

---

## Repository Contents

| File / Directory | Description |
|------------------|-------------|
| [`PCIE1.md`](PCIE1.md) | Comprehensive PCIe 1.0 protocol study |
| [`PLAN.md`](PLAN.md) | Detailed Verilog implementation and testbench plan |
| `rtl/` | Synthesizable Verilog RTL (PHY / DLL / TL layers + top) |
| `tb/` | Testbench: RC BFM, link model, monitor, and 10 test cases |
| `scripts/` | Shell scripts to build and run simulations with iverilog |

---

## PCIe 1.0 at a Glance

PCI Express 1.0 (2003) introduced a **point-to-point serial** interconnect to replace the
shared parallel PCI bus:

| Parameter | Value |
|-----------|-------|
| Line rate per lane | 2.5 GT/s |
| Encoding | 8b/10b (20% overhead) |
| Effective bandwidth (×1) | 250 MB/s per direction |
| Max link width | ×32 (×16 for GPUs) |
| Layers | Physical · Data Link · Transaction |

See [`PCIE1.md`](PCIE1.md) for the full protocol study covering:
- Physical Layer (8b/10b, scrambling, LTSSM)
- Data Link Layer (ACK/NAK, CRC, flow control)
- Transaction Layer (TLP formats, ordering, configuration space)
- Error handling, power management, MSI/MSI-X

---

## Implementation Overview

The RTL targets a **PCIe 1.0 ×1 Endpoint** and is organized into three layers
mirroring the PCIe specification:

```
Application
    │
┌───▼──────────────────────────────────┐
│          Transaction Layer            │  TLP generation, config space, MSI
└───────────────────┬──────────────────┘
                    │
┌───────────────────▼──────────────────┐
│           Data Link Layer             │  ACK/NAK, CRC-32, flow control
└───────────────────┬──────────────────┘
                    │
┌───────────────────▼──────────────────┐
│            Physical Layer             │  8b/10b, scrambler, LTSSM
└──────────────────────────────────────┘
```

See [`PLAN.md`](PLAN.md) for:
- Full directory and module hierarchy
- Interface definitions for every module
- 10 detailed test cases (8b/10b, LTSSM, ACK/NAK, flow control, MRd/MWr, Config, MSI, errors)
- Build and simulation flow using iverilog
- Verification coverage plan and milestones

---

## Quick Start

### Prerequisites

```bash
sudo apt-get install iverilog gtkwave
```

### Run All Tests

```bash
./scripts/run_all.sh
```

Regression summary (including completed and incompleted simulations) is saved to:

```bash
results/simulation_results.txt
```

### Run a Single Test Case

```bash
./scripts/run_tc.sh tc_cfg_access
```

### View Waveforms

```bash
./scripts/view_waves.sh dump.vcd
```

---

## Test Cases

| ID | Name | Feature Tested |
|----|------|----------------|
| TC-01 | `tc_8b10b` | 8b/10b encoder/decoder — all 256 codes + K-codes |
| TC-02 | `tc_scrambler` | LFSR scrambler/descrambler round-trip |
| TC-03 | `tc_ltssm` | Link training: Detect → Polling → Config → L0 |
| TC-04 | `tc_flow_ctrl` | Flow control InitFC/UpdateFC, credit backpressure |
| TC-05 | `tc_ack_nak` | ACK/NAK retry, replay buffer, replay timeout |
| TC-06 | `tc_cfg_access` | Configuration Read/Write, BAR sizing |
| TC-07 | `tc_mem_write` | Memory Write (posted) TLP |
| TC-08 | `tc_mem_read` | Memory Read + CplD, split completions |
| TC-09 | `tc_msi` | MSI interrupt generation |
| TC-10 | `tc_error_handling` | LCRC errors, poisoned TLP, UR, completion timeout |

---

## References

- PCI Express Base Specification Revision 1.0a, PCI-SIG (2003)
- *PCI Express System Architecture*, Budruk / Anderson / Shanley (Addison-Wesley, 2003)
- See [`PCIE1.md § References`](PCIE1.md#17-references) for the full list
