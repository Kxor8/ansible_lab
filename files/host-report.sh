#!/bin/bash

set -e
umask 027

REPORT_DIR="/home/automation/reporting"
REPORT_FILE="$REPORT_DIR/report.log"

mkdir -p "$REPORT_DIR"

echo "timestamp=$(date -u +%s) host=$(hostname) phase=$1" >> "$REPORT_FILE"
