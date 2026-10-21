#!/bin/bash

# ==============================================================================
# CONFIGURATION (Must match your sync script settings)
# ==============================================================================
SSH_HOST="user@your-remote-server-ip"
REMOTE_SOURCE_DIR="/mnt/ZFS/Public/videos/TV"
MANIFEST_FILE="./sync_manifest.txt"
# ==============================================================================

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest file '$MANIFEST_FILE' not found."
    exit 1
fi

echo "=== Scanning remote source to build expected inventory... ==="
REMOTE_INVENTORY=$(mktemp)
SORTED_REMOTE=$(mktemp)
SORTED_MANIFEST=$(mktemp)
MISSING_ITEMS=$(mktemp)

# Generate remote relative paths using the exact same season-aware logic via Python
ssh -o ControlMaster=auto -o ControlPath="/tmp/ssh_control_%h_%p_%r" -o ControlPersist=10m "$SSH_HOST" "REMOTE_BASE='$REMOTE_SOURCE_DIR' python3 -" << 'EOF' > "$REMOTE_INVENTORY"
import os

remote_base = os.environ.get("REMOTE_BASE")
try:
    entries = sorted(os.listdir(remote_base))
except Exception:
    entries = []

for entry_name in entries:
    entry_path = os.path.join(remote_base, entry_name)
    if not os.path.isdir(entry_path):
        continue
    
    try:
        subdirs = [os.path.join(entry_path, d) for d in os.listdir(entry_path) if os.path.isdir(os.path.join(entry_path, d))]
    except Exception:
        subdirs = []
        
    items = subdirs if subdirs else [entry_path]
    for item in items:
        # Print path relative to remote base
        rel_path = os.path.relpath(item, remote_base)
        print(rel_path)
EOF

# Sort both files to prepare for comparison
sort "$REMOTE_INVENTORY" > "$SORTED_REMOTE"
sort "$MANIFEST_FILE" > "$SORTED_MANIFEST"

# Find items present in remote inventory but missing from the manifest
comm -23 "$SORTED_REMOTE" "$SORTED_MANIFEST" > "$MISSING_ITEMS"

# Calculate totals
total_remote=$(wc -l < "$SORTED_REMOTE")
total_logged=$(wc -l < "$SORTED_MANIFEST")
total_missing=$(wc -l < "$MISSING_ITEMS")

echo "=================================================="
echo "               VALIDATION REPORT                  "
echo "=================================================="
echo "Total items found on remote source: $total_remote"
echo "Total items recorded in manifest:   $total_logged"
echo "Items NOT YET in manifest (gaps):   $total_missing"
echo "=================================================="

if [ "$total_missing" -eq 0 ]; then
    echo " SUCCESS: Every single remote item is accounted for in the manifest!"
else
    echo "️ NOTICE: The following items are in the remote source but NOT in your manifest:"
    echo "--------------------------------------------------"
    cat "$MISSING_ITEMS"
    echo "--------------------------------------------------"
    echo "(Note: If you are still waiting to run Drive 2, these are likely the items left over for it.)"
fi

# Cleanup temp files
rm -f "$REMOTE_INVENTORY" "$SORTED_REMOTE" "$SORTED_MANIFEST" "$MISSING_ITEMS"