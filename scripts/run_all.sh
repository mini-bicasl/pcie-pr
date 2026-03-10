#!/bin/bash
set -eu
PASS=0
FAIL=0
for TC in tc_8b10b tc_scrambler tc_ltssm tc_ack_nak tc_flow_ctrl \
          tc_mem_write tc_mem_read tc_cfg_access tc_msi tc_error_handling; do
    if ./scripts/run_tc.sh "$TC"; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
    fi
done
echo ""
echo "Results: PASS=$PASS  FAIL=$FAIL"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
