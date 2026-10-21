#!/bin/bash

# Configuration
REMOTE_USER="ladmin"
REMOTE_HOST="192.168.2.4"
LOCAL_ROOT="/media/usb/"

# Define the list of remote directories to sync (relative or absolute paths)
# Example: ("/home/user/docs" "/var/www/html" "/opt/data")
REMOTE_DIRS=(
"/mnt/ZFS/cloud"
"/mnt/ZFS/Private"
"/mnt/ZFS/DataArchive"
"/mnt/ZFS/Documents"
"/mnt/ZFS/Software"
"/mnt/ZFS/Public/pictures"
"/mnt/ZFS/Public/audio"
)

SSH_SOCKET_DIR="$HOME/.ssh/sockets"
SSH_SOCKET="$SSH_SOCKET_DIR/${REMOTE_USER}@${REMOTE_HOST}"

# 1. Prompt for Password Interactively
read -s -p "Enter SSH password for ${REMOTE_USER}@${REMOTE_HOST}: " SSHPASS
echo # Newline for clean output
export SSHPASS

# 2. Prepare SSH ControlSocket directory
mkdir -p "$SSH_SOCKET_DIR"

# 3. Establish the Master SSH Connection
sshpass -e ssh -M -N -f -o StrictHostKeyChecking=no -o "ControlPath=$SSH_SOCKET" "$REMOTE_USER@$REMOTE_HOST"

if [ $? -ne 0 ]; then
echo "Failed to establish master SSH connection."
unset SSHPASS
exit 1
fi

echo "Master connection established. Starting sync..."

# 4. Loop through each directory and rsync
for REMOTE_DIR in "${REMOTE_DIRS[@]}"; do
# Extract only the last part of the path (e.g., "Documents" from "/mnt/ZFS/Documents")
LOCAL_FOLDER=$(basename "$REMOTE_DIR")
TARGET_DIR="${LOCAL_ROOT}${LOCAL_FOLDER}"

echo "Syncing ${REMOTE_DIR} -> ${TARGET_DIR}"

# Create local target directory
mkdir -p "$TARGET_DIR"

# Run rsync
# Note: The trailing slash on REMOTE_DIR ensures we copy the *contents* of the remote folder
# into the local folder.
rsync -avz --progress \
-e "ssh -o ControlPath=$SSH_SOCKET" \
"$REMOTE_USER@$REMOTE_HOST:${REMOTE_DIR}/" \
"$TARGET_DIR/"

if [ $? -ne 0 ]; then
echo "Warning: Sync failed for ${REMOTE_DIR}"
fi
done

# 5. Close the Master Connection
ssh -O exit -o "ControlPath=$SSH_SOCKET" "$REMOTE_USER@$REMOTE_HOST"

# 6. Cleanup
unset SSHPASS
echo "All sync operations completed."