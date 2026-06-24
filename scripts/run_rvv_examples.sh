#!/usr/bin/env bash
#
# Run all SLOTHY examples whose name contains "rvv", in parallel.
#
# Each example is run as `python3 example.py --examples <name>`. Jobs are
# distributed across cores, one example per worker. Per-example stdout/stderr
# is captured into a log directory, and a summary is printed at the end.
#
# Usage:
#   scripts/run_rvv_examples.sh [-j N] [-r] [-- extra args passed to example.py]
#
#   -j N            Number of parallel jobs (default: number of cores).
#   -r, --rerun-failed
#                   Re-run only the examples that failed in the previous run
#                   (read from rvv_run_logs/summary.txt).
#
# Examples:
#   scripts/run_rvv_examples.sh
#   scripts/run_rvv_examples.sh -j 4
#   scripts/run_rvv_examples.sh -r
#   scripts/run_rvv_examples.sh -j 4 -- --timeout 300

set -u

# Resolve repo root (this script lives in scripts/).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Defaults.
JOBS="$(nproc 2>/dev/null || echo 4)"
RERUN_FAILED=0
EXTRA_ARGS=()

# Parse args.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -j)
            JOBS="$2"; shift 2 ;;
        -j*)
            JOBS="${1#-j}"; shift ;;
        -r|--rerun-failed)
            RERUN_FAILED=1; shift ;;
        --)
            shift; EXTRA_ARGS=("$@"); break ;;
        -h|--help)
            sed -n '2,24p' "$0"; exit 0 ;;
        *)
            echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done

PYTHON="${PYTHON:-python3}"
LOG_DIR="$REPO_ROOT/rvv_run_logs"
SUMMARY="$LOG_DIR/summary.txt"

if [[ $RERUN_FAILED -eq 1 ]]; then
    # Re-run only the examples that failed in the previous run.
    if [[ ! -f "$SUMMARY" ]]; then
        echo "No previous summary at $SUMMARY; run without -r first." >&2
        exit 1
    fi
    mapfile -t EXAMPLES < <(awk '/^FAIL/ {print $2}' "$SUMMARY")
    if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
        echo "No failed examples in the previous run. Nothing to re-run."
        exit 0
    fi
else
    # Discover all example names containing "rvv" from example.py's help output.
    mapfile -t EXAMPLES < <(
        "$PYTHON" example.py --help 2>&1 \
            | tr ',' '\n' \
            | grep -i 'rvv' \
            | sed "s/[][' ]//g" \
            | grep -E '^[A-Za-z0-9_]+$'
    )
    if [[ ${#EXAMPLES[@]} -eq 0 ]]; then
        echo "No examples containing 'rvv' found." >&2
        exit 1
    fi
fi

mkdir -p "$LOG_DIR"

if [[ $RERUN_FAILED -eq 1 ]]; then
    echo "Re-running ${#EXAMPLES[@]} previously failed examples with -j $JOBS."
else
    echo "Found ${#EXAMPLES[@]} rvv examples. Running with -j $JOBS."
fi
echo "Logs: $LOG_DIR"
echo

# Worker: run a single example, capture output, report status.
run_one() {
    local name="$1"
    local log="$LOG_DIR/${name}.log"
    local start end rc
    start=$SECONDS
    if "$PYTHON" example.py --examples "$name" "${EXTRA_ARGS[@]}" >"$log" 2>&1; then
        rc=0
    else
        rc=$?
    fi
    end=$SECONDS
    if [[ $rc -eq 0 ]]; then
        printf 'PASS  %-50s %4ds\n' "$name" "$((end - start))"
    else
        printf 'FAIL  %-50s %4ds (rc=%d, see %s)\n' "$name" "$((end - start))" "$rc" "$log"
    fi
    return $rc
}
export -f run_one
export PYTHON LOG_DIR
# Export extra args for the subshells (bash arrays don't export; serialize).
export EXTRA_ARGS_STR="${EXTRA_ARGS[*]}"

# xargs spawns subshells that don't inherit the EXTRA_ARGS bash array, so
# re-parse it inside each worker from the serialized string.
run_one_wrapper() {
    # shellcheck disable=SC2206
    EXTRA_ARGS=($EXTRA_ARGS_STR)
    run_one "$1"
}
export -f run_one_wrapper

START_ALL=$SECONDS
printf '%s\n' "${EXAMPLES[@]}" \
    | xargs -P "$JOBS" -I{} bash -c 'run_one_wrapper "$@"' _ {} \
    | tee "$LOG_DIR/summary.txt"
END_ALL=$SECONDS

echo
PASS=$(grep -c '^PASS' "$LOG_DIR/summary.txt" || true)
FAIL=$(grep -c '^FAIL' "$LOG_DIR/summary.txt" || true)
echo "Done in $((END_ALL - START_ALL))s: $PASS passed, $FAIL failed (of ${#EXAMPLES[@]})."

[[ "$FAIL" -eq 0 ]]
