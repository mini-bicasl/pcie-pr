#!/bin/bash
set -eu

TC=${1:-}
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

SIM_BIN="/tmp/sim_${TC}"
if ! iverilog -g2012 -Wall $RTL_FILES tb/tc/${TC}.v -o "$SIM_BIN"; then
    echo "FAIL: ${TC} (compile)"
    exit 1
fi
if ! vvp "$SIM_BIN"; then
    echo "FAIL: ${TC} (simulation)"
    exit 1
fi
echo "PASS: ${TC}"
