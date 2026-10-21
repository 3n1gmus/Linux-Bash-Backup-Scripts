#!/bin/bash

# ==============================================================================
# CONFIGURATION (Change these variables for any dataset/transfer)
# ==============================================================================
SSH_HOST="ladmin@192.168.2.4"
REMOTE_SOURCE_DIR="/mnt/ZFS/Public/videos/TV"     # Remote path to copy from
LOCAL_MOUNT="/media/usb"                        # Standard mount point for your drives
LOCAL_DEST_SUBPATH="videos/TV"           # Destination path relative to local mount
MANIFEST_FILE="./sync_manifest.txt"           # Central log file tracking copied items
SAFETY_BUFFER_GB=2                              # Free space buffer to leave on the drive
# ==============================================================================

LOCAL_DEST_DIR="$LOCAL_MOUNT/$LOCAL_DEST_SUBPATH"

# Ensure the drive is mounted before proceeding
if ! mountpoint -q "$LOCAL_MOUNT"; then
echo "Error: Nothing is mounted at $LOCAL_MOUNT. Please plug in your drive."
exit 1
fi

mkdir -p "$LOCAL_DEST_DIR"
touch "$MANIFEST_FILE"

echo "=== Target mount verified at: $LOCAL_MOUNT ==="
echo "=== Scanning source: $REMOTE_SOURCE_DIR ==="

TEMP_LIST=$(mktemp)

# Pass the remote source directory securely to Python via environment variable
export REMOTE_BASE="$REMOTE_SOURCE_DIR"

# Pipe Python script via stdin to SSH (100% immune to apostrophes, spaces, and brackets)
ssh -o ControlMaster=auto -o ControlPath="/tmp/ssh_control_%h_%p_%r" -o ControlPersist=10m "$SSH_HOST" "REMOTE_BASE='$REMOTE_SOURCE_DIR' python3 -" << 'EOF' > "$TEMP_LIST"
import os
import subprocess

remote_base = os.environ.get("REMOTE_BASE")
try:
entries = sorted(os.listdir(remote_base))
except Exception:
entries = []

for entry_name in entries:
entry_path = os.path.join(remote_base, entry_name)
if not os.path.exists(entry_path):
continue

# If it's a directory, check for subfolders (e.g., seasons/albums) for granular packing
if os.path.isdir(entry_path):
try:
subdirs = [os.path.join(entry_path, d) for d in os.listdir(entry_path) if os.path.isdir(os.path.join(entry_path, d))]
except Exception:
subdirs = []
items = subdirs if subdirs else [entry_path]
else:
items = [entry_path]

for item in items:
try:
res = subprocess.run(["du", "-s", item], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
if res.returncode == 0:
parts = res.stdout.split()
if parts:
print(f"{parts[0]}|{item}")
except Exception:
pass
EOF

# Filter out already logged items into a processing list
FINAL_LIST=$(mktemp)
while IFS='|' read -r item_size_kb item_path; do
[ -z "$item_path" ] && continue
rel_path="${item_path#$REMOTE_SOURCE_DIR/}"

# Skip if already logged in manifest or already exists on this specific drive
if grep -qFx "$rel_path" "$MANIFEST_FILE" || [ -e "$LOCAL_DEST_DIR/$rel_path" ]; then
continue
fi

echo "$item_size_kb|$item_path|$rel_path" >> "$FINAL_LIST"
done < "$TEMP_LIST"
rm -f "$TEMP_LIST"

echo "=== Sorting items by size (smallest first for optimal packing) ==="
sort -n "$FINAL_LIST" | while IFS='|' read -r item_size_kb item_path rel_path; do

avail_space_kb=$(df "$LOCAL_MOUNT" | awk 'NR==2 {print $4}')
effective_space_kb=$(( avail_space_kb - (SAFETY_BUFFER_GB * 1024 * 1024) ))

echo "--------------------------------------------------"
echo "Checking: '$rel_path'"
echo "Size: $(( item_size_kb / 1024 / 1024 )) GB"
echo "Drive Space Left (with ${SAFETY_BUFFER_GB}GB buffer): $(( effective_space_kb / 1024 / 1024 )) GB"

if [ "$item_size_kb" -le "$effective_space_kb" ]; then
echo "--> Fits! Copying to current drive..."
mkdir -p "$LOCAL_DEST_DIR/$(dirname "$rel_path")"

# rsync using ControlMaster socket
rsync -avh --progress -e "ssh -o ControlPath=/tmp/ssh_control_%h_%p_%r" "$SSH_HOST:$item_path/" "$LOCAL_DEST_DIR/$rel_path/"

# Log success to the central manifest so the next drive skips it
echo "$rel_path" >> "$MANIFEST_FILE"
else
echo "--> SKIPPED: Too big for remaining space on this drive. Saving for the next drive."
fi
done

rm -f "$FINAL_LIST"
echo "--------------------------------------------------"
echo "=== Sync Pass Complete for $LOCAL_MOUNT! ==="