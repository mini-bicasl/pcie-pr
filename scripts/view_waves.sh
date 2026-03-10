#!/bin/bash
set -eu
VCD_FILE=${1:-dump.vcd}
if [ ! -f "$VCD_FILE" ]; then
    echo "VCD file not found: $VCD_FILE"
    exit 1
fi
gtkwave "$VCD_FILE" &
