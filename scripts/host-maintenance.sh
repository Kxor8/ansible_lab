#!/bin/bash

set -e

READY_FILE="/home/automation/maintenance-ready"
REPORT_DIR="/home/automation/maintenance-run"
REPORT_FILE="$REPORT_DIR/report.txt"

LABEL="$1"

if [ ! -f "$READY_FILE" ]; then
    echo "ERROR: Maintenance readiness file is missing"
    exit 42
fi

mkdir -p "$REPORT_DIR"

echo "host=$(hostname)" > "$REPORT_FILE"
echo "label=$LABEL" >> "$REPORT_FILE"

chmod 0640 "$REPORT_FILE"

echo "Maintenance completed successfully on $(hostname)"
