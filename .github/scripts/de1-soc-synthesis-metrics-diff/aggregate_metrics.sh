#!/bin/bash
# Build a single comparison report table from per-config metric diff artifacts.
# Usage: aggregate_metrics.sh [artifacts_dir] [output_file]

set -euo pipefail

ARTIFACTS_DIR="${1:-metrics-diff}"
OUTPUT_FILE="${2:-comparison.md}"

append_metric_cell() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "<em>missing</em>" >> "$OUTPUT_FILE"
    return
  fi

  cat "$file" >> "$OUTPUT_FILE"
}

echo "## 🔧 DE1-SoC Synthesis Report Summary Diff" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "<table>" >> "$OUTPUT_FILE"
echo "  <thead>" >> "$OUTPUT_FILE"
echo "    <tr>" >> "$OUTPUT_FILE"
echo "      <th>Config</th>" >> "$OUTPUT_FILE"
echo "      <th>Fitter Summary</th>" >> "$OUTPUT_FILE"
echo "      <th>Fitter by entity</th>" >> "$OUTPUT_FILE"
echo "      <th>Timing</th>" >> "$OUTPUT_FILE"
echo "    </tr>" >> "$OUTPUT_FILE"
echo "  </thead>" >> "$OUTPUT_FILE"
echo "  <tbody>" >> "$OUTPUT_FILE"

found_any=false
while IFS= read -r dir; do
  found_any=true
  config="${dir##*de1-soc-synthesis-metrics-diff-}"

  echo "    <tr>" >> "$OUTPUT_FILE"
  echo "      <td><code>${config}</code></td>" >> "$OUTPUT_FILE"
  echo "      <td>" >> "$OUTPUT_FILE"
  echo "        <details><summary>View</summary>" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/fitter_summary.md"
  echo "        </details>" >> "$OUTPUT_FILE"
  echo "      </td>" >> "$OUTPUT_FILE"
  echo "      <td>" >> "$OUTPUT_FILE"
  echo "        <details><summary>View</summary>" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/fitter_by_entity.md"
  echo "        </details>" >> "$OUTPUT_FILE"
  echo "      </td>" >> "$OUTPUT_FILE"
  echo "      <td>" >> "$OUTPUT_FILE"
  echo "        <details><summary>View</summary>" >> "$OUTPUT_FILE"
  append_metric_cell "$dir/timing_summary.md"
  echo "        </details>" >> "$OUTPUT_FILE"
  echo "      </td>" >> "$OUTPUT_FILE"
  echo "    </tr>" >> "$OUTPUT_FILE"
done < <(find "$ARTIFACTS_DIR" -mindepth 1 -maxdepth 1 -type d -name 'de1-soc-synthesis-metrics-diff-*' | sort)

if [ "$found_any" = false ]; then
  echo "    <tr>" >> "$OUTPUT_FILE"
  echo "      <td>N/A</td>" >> "$OUTPUT_FILE"
  echo "      <td><em>No metrics diff artifacts found</em></td>" >> "$OUTPUT_FILE"
  echo "      <td><em>No metrics diff artifacts found</em></td>" >> "$OUTPUT_FILE"
  echo "      <td><em>No metrics diff artifacts found</em></td>" >> "$OUTPUT_FILE"
  echo "    </tr>" >> "$OUTPUT_FILE"
fi

echo "  </tbody>" >> "$OUTPUT_FILE"
echo "</table>" >> "$OUTPUT_FILE"

echo "" >> "$OUTPUT_FILE"
echo "---" >> "$OUTPUT_FILE"
echo "*Comparing synthesis results from main branch vs. this PR*" >> "$OUTPUT_FILE"
