#!/usr/bin/env bash
# clean-legacy-bundles.sh
#
# Removes legacy/broken Agentforce bundle directories so `sf project deploy start`
# only picks up the two active agents:
#   - Warranty_Dealer_Intake_Agentt_4   (ARIA, dealer-facing on WhatsApp)
#   - Warranty_Approver_Agent_3         (OEM approver, Slack)
#
# Safe to run multiple times. Takes the aiAuthoringBundles path as $1
# (defaults to ./force-app/main/default/aiAuthoringBundles).
#
# Usage:
#   ./clean-legacy-bundles.sh
#   ./clean-legacy-bundles.sh path/to/aiAuthoringBundles

set -eu

BUNDLE_DIR="${1:-./force-app/main/default/aiAuthoringBundles}"

if [ ! -d "$BUNDLE_DIR" ]; then
    echo "ERROR: Bundle directory not found: $BUNDLE_DIR" >&2
    exit 1
fi

KEEP=(
    "Warranty_Dealer_Intake_Agentt_4"
    "Warranty_Approver_Agent_3"
)

echo "Scanning $BUNDLE_DIR..."
removed=0
kept=0

for entry in "$BUNDLE_DIR"/*/; do
    name="$(basename "$entry")"
    keep_it=false
    for k in "${KEEP[@]}"; do
        if [ "$name" = "$k" ]; then
            keep_it=true
            break
        fi
    done

    if [ "$keep_it" = true ]; then
        echo "  KEEP    $name"
        kept=$((kept + 1))
    else
        echo "  REMOVE  $name"
        rm -rf "$entry"
        removed=$((removed + 1))
    fi
done

echo ""
echo "Done. Kept $kept, removed $removed."
