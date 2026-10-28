#!/usr/bin/env bash
# Full DevSecOps Security Pipeline
# Runs all security checks and generates a unified report
#
# Usage:
#   ./security_pipeline.sh                     # Scan current directory
#   ./security_pipeline.sh --image nginx:latest # Also scan Docker image
#   ./security_pipeline.sh --fail-on critical   # Exit 1 if critical issues found
#   ./security_pipeline.sh --report report.json # Save JSON report

set -euo pipefail

# ─────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────
SCAN_DIR="${SCAN_DIR:-.}"
IMAGE="${IMAGE:-}"
FAIL_ON="${FAIL_ON:-critical}"   # critical, high, medium, or none
REPORT_FILE="${REPORT_FILE:-security-report.json}"
VERBOSE="${VERBOSE:-false}"

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Result tracking
FINDINGS=0
CRITICAL_COUNT=0
HIGH_COUNT=0
FAILED_TOOLS=()
PASSED_TOOLS=()

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --image) IMAGE="$2"; shift 2 ;;
        --fail-on) FAIL_ON="$2"; shift 2 ;;
        --report) REPORT_FILE="$2"; shift 2 ;;
        --verbose) VERBOSE="true"; shift ;;
        *) SCAN_DIR="$1"; shift ;;
    esac
done

# ─────────────────────────────────────────
# Helper functions
# ─────────────────────────────────────────
log_section() {
    echo ""
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
}

log_pass() { echo -e "  ${GREEN}✓${NC} $1"; PASSED_TOOLS+=("$1"); }
log_fail() { echo -e "  ${RED}✗${NC} $1: $2"; FAILED_TOOLS+=("$1"); ((FINDINGS++)); }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
log_skip() { echo -e "  ${BLUE}○${NC} $1 (skipped - not installed)"; }

check_tool() { command -v "$1" &>/dev/null; }

start_time=$(date +%s)
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     AK Dev Toolkit Security Pipeline     ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "  Scan target: $SCAN_DIR"
echo "  Fail on:     $FAIL_ON"
echo "  Timestamp:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ─────────────────────────────────────────
# 1. SECRET SCANNING
# ─────────────────────────────────────────
log_section "1. Secret Scanning"

if check_tool gitleaks; then
    GITLEAKS_OUT=$(mktemp)
    if gitleaks detect --source "$SCAN_DIR" --report-format json \
        --report-path "$GITLEAKS_OUT" --no-banner 2>/dev/null; then
        log_pass "gitleaks: No secrets found"
    else
        SECRET_COUNT=$(jq 'length' "$GITLEAKS_OUT" 2>/dev/null || echo "?")
        log_fail "gitleaks" "$SECRET_COUNT secrets detected"
        ((CRITICAL_COUNT += SECRET_COUNT))
        if [ "$VERBOSE" = "true" ]; then
            jq -r '.[] | "    [\(.RuleID)] \(.File):\(.StartLine) — \(.Description)"' "$GITLEAKS_OUT" 2>/dev/null || true
        fi
    fi
    rm -f "$GITLEAKS_OUT"
else
    log_skip "gitleaks (install: brew install gitleaks)"
fi

if check_tool trufflehog; then
    if trufflehog filesystem "$SCAN_DIR" --only-verified --no-update 2>/dev/null | grep -q "Found"; then
        log_fail "trufflehog" "Verified secrets found — check output above"
        ((CRITICAL_COUNT++))
    else
        log_pass "trufflehog: No verified secrets"
    fi
else
    log_skip "trufflehog (install: pip install trufflesecurity)"
fi

# ─────────────────────────────────────────
# 2. SAST (Static Analysis)
# ─────────────────────────────────────────
log_section "2. Static Analysis (SAST)"

if check_tool semgrep; then
    SEMGREP_OUT=$(mktemp)
    semgrep --config p/security-audit "$SCAN_DIR" \
        --json > "$SEMGREP_OUT" 2>/dev/null || true

    SEMGREP_ERRORS=$(jq '.errors | length' "$SEMGREP_OUT" 2>/dev/null || echo 0)
    SEMGREP_FINDINGS=$(jq '.results | length' "$SEMGREP_OUT" 2>/dev/null || echo 0)

    if [ "$SEMGREP_FINDINGS" -eq 0 ]; then
        log_pass "semgrep: No security issues found"
    else
        CRITICAL_SEMGREP=$(jq '[.results[] | select(.extra.severity == "ERROR")] | length' "$SEMGREP_OUT" 2>/dev/null || echo 0)
        log_fail "semgrep" "$SEMGREP_FINDINGS issues ($CRITICAL_SEMGREP critical)"
        ((HIGH_COUNT += SEMGREP_FINDINGS))
        if [ "$VERBOSE" = "true" ]; then
            jq -r '.results[] | "    [\(.extra.severity)] \(.path):\(.start.line) — \(.check_id)"' "$SEMGREP_OUT" 2>/dev/null | head -20 || true
        fi
    fi
    rm -f "$SEMGREP_OUT"
else
    log_skip "semgrep (install: pip install semgrep)"
fi

# Python-specific
if check_tool bandit && find "$SCAN_DIR" -name "*.py" | head -1 | grep -q .; then
    BANDIT_OUT=$(mktemp)
    bandit -r "$SCAN_DIR" -f json -o "$BANDIT_OUT" -ll 2>/dev/null || true
    BANDIT_HIGH=$(jq '.results | map(select(.issue_severity == "HIGH")) | length' "$BANDIT_OUT" 2>/dev/null || echo 0)
    BANDIT_CRITICAL=$(jq '.results | map(select(.issue_severity == "HIGH" and .issue_confidence == "HIGH")) | length' "$BANDIT_OUT" 2>/dev/null || echo 0)

    if [ "$BANDIT_HIGH" -eq 0 ]; then
        log_pass "bandit: No high-severity Python issues"
    else
        log_fail "bandit" "$BANDIT_HIGH high-severity Python issues"
        ((HIGH_COUNT += BANDIT_HIGH))
    fi
    rm -f "$BANDIT_OUT"
elif find "$SCAN_DIR" -name "*.py" | head -1 | grep -q .; then
    log_skip "bandit (install: pip install bandit)"
fi

# ─────────────────────────────────────────
# 3. DEPENDENCY SCANNING (SCA)
# ─────────────────────────────────────────
log_section "3. Dependency Scanning (SCA)"

# Python
if [ -f "$SCAN_DIR/requirements.txt" ] || [ -f "$SCAN_DIR/pyproject.toml" ]; then
    if check_tool pip; then
        SAFETY_OUT=$(pip-audit --format json 2>/dev/null) || true
        if [ -z "$SAFETY_OUT" ] || echo "$SAFETY_OUT" | jq -e '.[] | length == 0' &>/dev/null; then
            log_pass "pip-audit: No vulnerable Python packages"
        else
            VULN_COUNT=$(echo "$SAFETY_OUT" | jq 'length' 2>/dev/null || echo "?")
            log_fail "pip-audit" "$VULN_COUNT vulnerable packages"
            ((HIGH_COUNT += VULN_COUNT))
        fi
    fi
fi

# Node.js
if [ -f "$SCAN_DIR/package.json" ]; then
    if check_tool npm; then
        NPM_OUT=$(npm audit --json 2>/dev/null || true)
        CRITICAL_NPM=$(echo "$NPM_OUT" | jq '.metadata.vulnerabilities.critical // 0' 2>/dev/null || echo 0)
        HIGH_NPM=$(echo "$NPM_OUT" | jq '.metadata.vulnerabilities.high // 0' 2>/dev/null || echo 0)

        if [ "$CRITICAL_NPM" -eq 0 ] && [ "$HIGH_NPM" -eq 0 ]; then
            log_pass "npm audit: No critical/high vulnerabilities"
        else
            log_fail "npm audit" "$CRITICAL_NPM critical, $HIGH_NPM high vulnerabilities"
            ((CRITICAL_COUNT += CRITICAL_NPM))
            ((HIGH_COUNT += HIGH_NPM))
        fi
    fi
fi

# ─────────────────────────────────────────
# 4. IAC SECURITY SCANNING
# ─────────────────────────────────────────
log_section "4. Infrastructure as Code Security"

if check_tool checkov; then
    CHECKOV_OUT=$(mktemp)
    checkov -d "$SCAN_DIR" --quiet --compact --output json > "$CHECKOV_OUT" 2>/dev/null || true
    CHECKOV_FAILED=$(jq '.summary.failed // 0' "$CHECKOV_OUT" 2>/dev/null || echo 0)

    if [ "$CHECKOV_FAILED" -eq 0 ]; then
        log_pass "checkov: No IaC misconfigurations"
    else
        log_fail "checkov" "$CHECKOV_FAILED IaC policy violations"
        ((HIGH_COUNT += CHECKOV_FAILED))
    fi
    rm -f "$CHECKOV_OUT"
else
    log_skip "checkov (install: pip install checkov)"
fi

if check_tool tfsec && find "$SCAN_DIR" -name "*.tf" | head -1 | grep -q .; then
    TFSEC_CRITICAL=$(tfsec "$SCAN_DIR" --minimum-severity CRITICAL --format json 2>/dev/null | jq '.results | length' || echo 0)
    if [ "$TFSEC_CRITICAL" -eq 0 ]; then
        log_pass "tfsec: No critical Terraform issues"
    else
        log_fail "tfsec" "$TFSEC_CRITICAL critical Terraform misconfigurations"
        ((CRITICAL_COUNT += TFSEC_CRITICAL))
    fi
fi

# ─────────────────────────────────────────
# 5. CONTAINER SECURITY
# ─────────────────────────────────────────
log_section "5. Container Security"

# Dockerfile lint
if check_tool hadolint && [ -f "$SCAN_DIR/Dockerfile" ]; then
    HADOLINT_OUT=$(hadolint --format json "$SCAN_DIR/Dockerfile" 2>/dev/null || true)
    HADOLINT_ERRORS=$(echo "$HADOLINT_OUT" | jq '[.[] | select(.level == "error")] | length' 2>/dev/null || echo 0)

    if [ "$HADOLINT_ERRORS" -eq 0 ]; then
        log_pass "hadolint: Dockerfile follows best practices"
    else
        log_fail "hadolint" "$HADOLINT_ERRORS Dockerfile errors"
        ((HIGH_COUNT += HADOLINT_ERRORS))
        if [ "$VERBOSE" = "true" ]; then
            echo "$HADOLINT_OUT" | jq -r '.[] | select(.level == "error") | "    [\(.code)] L\(.line): \(.message)"' || true
        fi
    fi
else
    log_skip "hadolint (install: brew install hadolint)"
fi

# Docker image scan
if [ -n "$IMAGE" ]; then
    if check_tool trivy; then
        TRIVY_OUT=$(mktemp)
        trivy image --quiet --format json --output "$TRIVY_OUT" \
            --severity CRITICAL,HIGH "$IMAGE" 2>/dev/null || true
        TRIVY_CRITICAL=$(jq '[.Results[].Vulnerabilities // [] | .[] | select(.Severity == "CRITICAL")] | length' "$TRIVY_OUT" 2>/dev/null || echo 0)
        TRIVY_HIGH=$(jq '[.Results[].Vulnerabilities // [] | .[] | select(.Severity == "HIGH")] | length' "$TRIVY_OUT" 2>/dev/null || echo 0)

        if [ "$TRIVY_CRITICAL" -eq 0 ] && [ "$TRIVY_HIGH" -eq 0 ]; then
            log_pass "trivy: No critical/high CVEs in image"
        else
            log_fail "trivy" "$TRIVY_CRITICAL critical, $TRIVY_HIGH high CVEs in $IMAGE"
            ((CRITICAL_COUNT += TRIVY_CRITICAL))
            ((HIGH_COUNT += TRIVY_HIGH))
        fi
        rm -f "$TRIVY_OUT"
    else
        log_skip "trivy (install: brew install trivy)"
    fi

    # Generate SBOM
    if check_tool syft; then
        SBOM_FILE="sbom-$(basename "$IMAGE" | tr ':' '-').spdx.json"
        syft "$IMAGE" -o spdx-json="$SBOM_FILE" 2>/dev/null
        log_pass "syft: SBOM generated → $SBOM_FILE"
    fi
fi

# ─────────────────────────────────────────
# 6. SUMMARY
# ─────────────────────────────────────────
end_time=$(date +%s)
duration=$((end_time - start_time))

echo ""
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo -e "${BLUE}  SECURITY SCAN SUMMARY${NC}"
echo -e "${BLUE}════════════════════════════════════════${NC}"
echo ""
echo "  Duration:     ${duration}s"
echo "  Tools passed: ${#PASSED_TOOLS[@]}"
echo "  Tools failed: ${#FAILED_TOOLS[@]}"
echo ""

if [ $CRITICAL_COUNT -gt 0 ]; then
    echo -e "  ${RED}CRITICAL: $CRITICAL_COUNT issues${NC}"
fi
if [ $HIGH_COUNT -gt 0 ]; then
    echo -e "  ${YELLOW}HIGH: $HIGH_COUNT issues${NC}"
fi
if [ $CRITICAL_COUNT -eq 0 ] && [ $HIGH_COUNT -eq 0 ]; then
    echo -e "  ${GREEN}No critical or high severity issues found!${NC}"
fi

echo ""

# Generate JSON report
cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "scan_dir": "$SCAN_DIR",
  "duration_seconds": $duration,
  "summary": {
    "critical": $CRITICAL_COUNT,
    "high": $HIGH_COUNT,
    "tools_passed": ${#PASSED_TOOLS[@]},
    "tools_failed": ${#FAILED_TOOLS[@]}
  },
  "passed_tools": $(printf '%s\n' "${PASSED_TOOLS[@]}" | jq -R . | jq -s .),
  "failed_tools": $(printf '%s\n' "${FAILED_TOOLS[@]}" | jq -R . | jq -s .)
}
EOF
echo "  Report saved: $REPORT_FILE"

# Determine exit code
case "$FAIL_ON" in
    critical) [ $CRITICAL_COUNT -gt 0 ] && exit 1 || exit 0 ;;
    high)     [ $((CRITICAL_COUNT + HIGH_COUNT)) -gt 0 ] && exit 1 || exit 0 ;;
    none)     exit 0 ;;
    *)        exit 0 ;;
esac
