#!/bin/bash
set -eu
PASS=0
FAIL=0
RESULTS_DIR="results"
RESULTS_FILE="${RESULTS_DIR}/simulation_results.txt"
TESTCASES=(
    tc_8b10b tc_scrambler tc_ltssm tc_ack_nak tc_flow_ctrl
    tc_mem_write tc_mem_read tc_cfg_access tc_msi tc_error_handling
    tc_multilane_phy
)
COMPLETED_CASES=()
INCOMPLETE_CASES=()

for TC in "${TESTCASES[@]}"; do
    if ./scripts/run_tc.sh "$TC"; then
        PASS=$((PASS+1))
        COMPLETED_CASES+=("$TC")
    else
        FAIL=$((FAIL+1))
        INCOMPLETE_CASES+=("$TC")
    fi
done

mkdir -p "$RESULTS_DIR"
{
    echo "Simulation Results ($(date -u +"%Y-%m-%dT%H:%M:%SZ"))"
    echo "PASS=$PASS FAIL=$FAIL TOTAL=${#TESTCASES[@]}"
    echo ""
    echo "Completed simulations (${#COMPLETED_CASES[@]}):"
    for TC in "${COMPLETED_CASES[@]}"; do
        echo "- $TC"
    done
    echo ""
    echo "Incomplete simulations (${#INCOMPLETE_CASES[@]}):"
    for TC in "${INCOMPLETE_CASES[@]}"; do
        echo "- $TC"
    done
} > "$RESULTS_FILE"

echo ""
echo "Results: PASS=$PASS  FAIL=$FAIL"
echo "Detailed results written to $RESULTS_FILE"
if [ "$FAIL" -ne 0 ]; then
    exit 1
fi
