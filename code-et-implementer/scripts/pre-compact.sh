#!/bin/bash
# Pre-compact hook - log state before context compaction
# Called on PreCompact hook

DATE=$(date +"%Y-%m-%d %H:%M")
BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

echo "{\"pre_compact\": \"Context compacting\", \"branch\": \"$BRANCH\", \"timestamp\": \"$DATE\"}"

exit 0
