#!/bin/bash
# Script to compare a synthesis report between main and PR branches
# Usage: compare_metrics_diff.sh <main_report_path> <pr_report_path> <human_readable_name> [emoji]
# Example: compare_metrics_diff.sh "main-reports/report.summary" "pr-reports/report.summary" "Fitter Summary" "📊"

set -e

if [ $# -lt 3 ]; then
  echo "Usage: $0 <main_report_path> <pr_report_path> <human_readable_name> [emoji]" >&2
  exit 1
fi

MAIN_REPORT="$1"
PR_REPORT="$2"
TITLE="$3"
EMOJI="${4:---}"

if [ ! -f "$PR_REPORT" ]; then
  echo "ERROR: PR report not found at $PR_REPORT" >&2
  exit 1
fi

{
  echo "<details>"
  echo "<summary><h3>$EMOJI $TITLE</h3></summary>"
  echo ""

  if [ -f "$MAIN_REPORT" ]; then
    # Generate diff and capture output
    DIFF_OUTPUT=$(diff -u "$MAIN_REPORT" "$PR_REPORT" | tail -n +3 || true)
    if [ -z "$DIFF_OUTPUT" ]; then
      echo "*No changes detected*"
    else
      echo "\`\`\`diff"
      echo "$DIFF_OUTPUT"
      echo "\`\`\`"
    fi
  else
    echo "*No baseline available from main branch*"
    echo ""
    echo "<details>"
    echo "<summary>View PR synthesis results</summary>"
    echo ""
    echo "\`\`\`"
    cat "$PR_REPORT"
    echo "\`\`\`"
    echo "</details>"
  fi
  echo ""
  echo "</details>"
  echo ""
}
