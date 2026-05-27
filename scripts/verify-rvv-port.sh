#!/usr/bin/env bash
# verify-rvv-port.sh — Forensic verification gate for a riscv64 RVV binary.
#
# v2: adds --hot-fn-exact / HOT_MATCH_MODE to distinguish substring (matches
#     family, e.g. PairLJCut::compute / compute_inner / compute_outer) from
#     exact match (single canonical function only).
#
# Applies a five-gate static check to any riscv64 ELF binary:
#   [1/5] Architecture                   — confirm ELF is UCB RISC-V
#   [2/5] Total RVV opcode count         — meet a minimum threshold
#   [3/5] Arith/setup ratio              — detect silent scalar fallback
#   [4/5] Backend selection canary       — confirm intended backend compiled in
#   [5/5] Hot-function RVV attribution   — confirm vectorization hits the
#                                          designated hot path (or honestly
#                                          confirm a documented zero)
#
# Usage:
#   verify-rvv-port.sh <config.conf> [flags...]
#   verify-rvv-port.sh --binary <path> --hot-fn <name> --min-total <N> [flags...]
#   verify-rvv-port.sh --table <c1.conf> <c2.conf> ...

set -euo pipefail

usage() {
    cat << 'EOF'
verify-rvv-port.sh — forensic verification for riscv64 RVV binaries

USAGE:
  verify-rvv-port.sh <config.conf> [flags]
  verify-rvv-port.sh --binary <path> --hot-fn <name> [flags]
  verify-rvv-port.sh --table <config1.conf> <config2.conf> ...

FLAGS (override config values):
  --binary <path>           Path to riscv64 ELF binary
  --port-name <name>        Short name (used in output)
  --min-total <N>           Minimum total RVV opcodes expected
  --hot-fn <name>           Demangled hot function name
  --hot-fn-exact            Match hot function exactly (default: substring)
  --expected-hot-ops <spec> "scalar" (must be 0), or a number (minimum)
                            Use a number with --hot-fn-exact for known-count
                            assertions (e.g., =24 for documented SLP ops)
  --backend-canary <regex>  Regex for backend-specific opcode (default: vsetvli)
  --table                   Markdown table row output (portfolio summary)
  --help                    This help

CONFIG FILE VARIABLES (all optional unless noted):
  PORT_NAME, BINARY (required), MIN_TOTAL_RVV (required),
  HOT_FUNCTION, HOT_MATCH_MODE (substring|exact), EXPECTED_HOT_OPS,
  BACKEND_CANARY

EXAMPLES:
  verify-rvv-port.sh ports/lammps.conf
  verify-rvv-port.sh ports/lammps.conf --hot-fn 'Verlet::run'
  verify-rvv-port.sh --table ports/*.conf > compliance.md
EOF
}

CLI_BINARY=""
CLI_PORT_NAME=""
CLI_MIN_TOTAL_RVV=""
CLI_HOT_FUNCTION=""
CLI_HOT_MATCH_MODE=""
CLI_EXPECTED_HOT_OPS=""
CLI_BACKEND_CANARY=""
TABLE_MODE=false
CONFIGS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --binary)            CLI_BINARY="$2"; shift 2 ;;
        --port-name)         CLI_PORT_NAME="$2"; shift 2 ;;
        --min-total)         CLI_MIN_TOTAL_RVV="$2"; shift 2 ;;
        --hot-fn)            CLI_HOT_FUNCTION="$2"; shift 2 ;;
        --hot-fn-exact)      CLI_HOT_MATCH_MODE="exact"; shift ;;
        --hot-fn-substring)  CLI_HOT_MATCH_MODE="substring"; shift ;;
        --expected-hot-ops)  CLI_EXPECTED_HOT_OPS="$2"; shift 2 ;;
        --backend-canary)    CLI_BACKEND_CANARY="$2"; shift 2 ;;
        --table)             TABLE_MODE=true; shift ;;
        --help|-h)           usage; exit 0 ;;
        --*)                 echo "ERROR: unknown flag: $1" >&2; usage; exit 2 ;;
        *)                   CONFIGS+=("$1"); shift ;;
    esac
done

OBJDUMP="${OBJDUMP:-riscv64-linux-gnu-objdump}"
CXXFILT="${CXXFILT:-c++filt}"

for tool in "$OBJDUMP" "$CXXFILT" file awk grep; do
    command -v "$tool" >/dev/null || {
        echo "ERROR: required tool not found: $tool" >&2
        exit 2
    }
done

verify_one() {
    local config="$1"

    # Reset defaults
    BINARY=""
    PORT_NAME=""
    MIN_TOTAL_RVV=0
    HOT_FUNCTION=""
    HOT_MATCH_MODE="substring"
    EXPECTED_HOT_OPS=""
    BACKEND_CANARY='vsetvli'

    if [ -n "$config" ]; then
        # shellcheck disable=SC1090
        source "$config"
    fi

    # CLI flags override config
    [ -n "$CLI_BINARY" ]            && BINARY="$CLI_BINARY"
    [ -n "$CLI_PORT_NAME" ]         && PORT_NAME="$CLI_PORT_NAME"
    [ -n "$CLI_MIN_TOTAL_RVV" ]     && MIN_TOTAL_RVV="$CLI_MIN_TOTAL_RVV"
    [ -n "$CLI_HOT_FUNCTION" ]      && HOT_FUNCTION="$CLI_HOT_FUNCTION"
    [ -n "$CLI_HOT_MATCH_MODE" ]    && HOT_MATCH_MODE="$CLI_HOT_MATCH_MODE"
    [ -n "$CLI_EXPECTED_HOT_OPS" ]  && EXPECTED_HOT_OPS="$CLI_EXPECTED_HOT_OPS"
    [ -n "$CLI_BACKEND_CANARY" ]    && BACKEND_CANARY="$CLI_BACKEND_CANARY"

    [ -n "$BINARY" ] || { echo "ERROR ($config): BINARY/--binary required" >&2; return 2; }
    [ -e "$BINARY" ] || { echo "ERROR ($config): binary not found: $BINARY" >&2; return 2; }
    [ -n "$PORT_NAME" ] || PORT_NAME=$(basename "$BINARY")

    local disasm
    disasm=$(mktemp)
    "$OBJDUMP" -d "$BINARY" 2>/dev/null | "$CXXFILT" > "$disasm"

    # ============ Gate 1: Architecture ============
    local result_arch g1
    if file "$BINARY" | grep -q "UCB RISC-V"; then
        result_arch="PASS"; g1=0
    else
        result_arch="FAIL"; g1=1
    fi

    # ============ Gate 2: Total RVV count ============
    local total_count result_total g2
    total_count=$(grep -cE '\<v(setvli|fmacc|fmul|fadd|fsub|le[0-9]+|se[0-9]+|fred)' "$disasm" || true)
    if [ "$total_count" -ge "$MIN_TOTAL_RVV" ]; then
        result_total="PASS ($total_count)"; g2=0
    else
        result_total="FAIL ($total_count<$MIN_TOTAL_RVV)"; g2=1
    fi

    # ============ Gate 3: Arith/setup ratio ============
    local arith_count setup_count ratio_pct result_ratio g3
    arith_count=$(grep -cE '\<v(fmacc|fmul|fadd|fsub|fred)' "$disasm" || true)
    setup_count=$(grep -cE '\<vsetvli' "$disasm" || true)
    if [ "$setup_count" -gt 0 ]; then
        ratio_pct=$(( 100 * arith_count / setup_count ))
    else
        ratio_pct=0
    fi
    if [ "$ratio_pct" -ge 10 ]; then
        result_ratio="PASS (${ratio_pct}%)"; g3=0
    else
        result_ratio="WARN (${ratio_pct}%)"; g3=0
    fi

    # ============ Gate 4: Backend canary ============
    local canary_count result_canary g4
    canary_count=$(grep -cE "$BACKEND_CANARY" "$disasm" || true)
    if [ "$canary_count" -gt 0 ]; then
        result_canary="PASS ($canary_count)"; g4=0
    else
        result_canary="FAIL (0)"; g4=1
    fi

    # ============ Gate 5: Hot function attribution ============
    local hot_count="" result_hot g5=0
    if [ -n "$HOT_FUNCTION" ]; then
        hot_count=$(awk -v fn="$HOT_FUNCTION" -v mode="$HOT_MATCH_MODE" '
            /^[0-9a-f]+ <.+>:/ {
                current=$0
                sub(/^[0-9a-f]+ </, "", current)
                sub(/>:$/, "", current)
                next
            }
            {
                if (mode == "exact") {
                    matches = (current == fn)
                } else {
                    matches = (index(current, fn) > 0)
                }
                if (matches && /\<v(setvli|fmacc|fmul|fadd|fsub|le[0-9]+|se[0-9]+|fred)/) c++
            }
            END { print c+0 }' "$disasm")

        case "$EXPECTED_HOT_OPS" in
            scalar)
                if [ "$hot_count" -eq 0 ]; then
                    result_hot="PASS (scalar:0)"; g5=0
                else
                    result_hot="FAIL (got $hot_count, expected scalar)"; g5=1
                fi
                ;;
            ''|0)
                result_hot="N/A ($hot_count)"; g5=0
                ;;
            =*)
                # Exact-count assertion (=N means must equal N)
                local expected_num="${EXPECTED_HOT_OPS:1}"
                if [ "$hot_count" -eq "$expected_num" ]; then
                    result_hot="PASS (=$expected_num)"; g5=0
                else
                    result_hot="FAIL ($hot_count != $expected_num)"; g5=1
                fi
                ;;
            *)
                if [ "$hot_count" -ge "$EXPECTED_HOT_OPS" ]; then
                    result_hot="PASS ($hot_count≥$EXPECTED_HOT_OPS)"; g5=0
                else
                    result_hot="FAIL ($hot_count<$EXPECTED_HOT_OPS)"; g5=1
                fi
                ;;
        esac
    else
        result_hot="(no hot fn)"
    fi

    rm -f "$disasm"

    local total_fails=$((g1 + g2 + g3 + g4 + g5))

    if $TABLE_MODE; then
        printf "| %s | %s | %s | %s | %s | %s |\n" \
            "$PORT_NAME" "$result_arch" "$result_total" \
            "$result_ratio" "$result_canary" "$result_hot"
    else
        echo "=== $PORT_NAME ==="
        echo "Binary:            $BINARY"
        echo "  [1/5] arch:      $result_arch"
        echo "  [2/5] total:     $result_total"
        echo "  [3/5] ratio:     $result_ratio  (arith=$arith_count / setup=$setup_count)"
        echo "  [4/5] canary:    $result_canary  (regex: $BACKEND_CANARY)"
        if [ -n "$HOT_FUNCTION" ]; then
            echo "  [5/5] hot fn:    $result_hot  (fn: $HOT_FUNCTION; mode: $HOT_MATCH_MODE; expect: ${EXPECTED_HOT_OPS:-any})"
        else
            echo "  [5/5] hot fn:    $result_hot"
        fi
        if [ "$total_fails" -eq 0 ]; then
            echo "  Result:          ✓ all gates passed"
        else
            echo "  Result:          ✗ $total_fails gate(s) failed"
        fi
        echo
    fi

    return "$total_fails"
}

if $TABLE_MODE; then
    echo "| Port | Arch | Total RVV | Arith/Setup | Backend Canary | Hot Fn |"
    echo "|---|---|---|---|---|---|"
fi

OVERALL_FAIL=0
if [ ${#CONFIGS[@]} -eq 0 ]; then
    verify_one "" || OVERALL_FAIL=$((OVERALL_FAIL + $?))
else
    for cfg in "${CONFIGS[@]}"; do
        verify_one "$cfg" || OVERALL_FAIL=$((OVERALL_FAIL + $?))
    done
fi

exit "$OVERALL_FAIL"
