#!/bin/bash

# --- Default Variables & Flags ---
MODE=""
PROTOCOL=""
TAR_GZ_FILE=""
CURRENT_HOSTNAME=$(hostname)
TARGET_HOSTNAME=$(hostname) # Defaults to current hostname, can be overridden
LOG_FILE="/var/log/Docker_Backup_Restore.log"
TEMPORARY_MOUNT_POINT="/mnt/temp_docker_storage"
CONFIG_FILE="./docker_storage.conf"

# --- Helper & Lifecycle Functions ---

usage() {
    echo "Usage: $0 -m <backup|restore> -p <cifs|nfs> [-f <restore_filename>] [-H <target_hostname>] [-c <config_file_path>]"
    echo "  -m : Mode execution (backup or restore)"
    echo "  -p : Storage protocol (cifs or nfs)"
    echo "  -f : Specific filename to extract (Required for restore mode)"
    echo "  -H : Override hostname folder on the share (Defaults to local hostname)"
    echo "  -c : Path to configuration file (Default: ./docker_storage.conf)"
    exit 1
}

log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - [$MODE/$PROTOCOL] - $1" | tee -a "$LOG_FILE"
}

setup_logrotate() {
    local log_base=$(basename "$LOG_FILE")
    local logrotate_config="/etc/logrotate.d/${log_base%.*}"

    if [ ! -f "$logrotate_config" ]; then
        echo "Creating logrotate configuration for '$log_base'..."
        sudo tee "$logrotate_config" > /dev/null <<EOL
"$LOG_FILE" {
    rotate 5
    daily
    compress
    missingok
    notifempty
}
EOL
    fi
}

stop_docker_containers() {
    log_message "Stopping all running Docker containers..."
    docker stop $(docker ps -q) 2>/dev/null || true
}

start_docker_containers() {
    log_message "Starting Docker containers..."
    if [ "$MODE" == "backup" ]; then
        docker start $(docker ps -aq) 2>/dev/null || true
    else
        docker start $(docker ps -a -q -f "status=exited") 2>/dev/null || true
    fi
}

update_and_prune_docker() {
    log_message "Updating Docker images..."
    local installed_images=$(docker images --format "{{.Repository}}")
    if [ -n "$installed_images" ]; then
        for image in $installed_images; do
            docker pull "$image" >/dev/null && log_message "Updated $image" || log_message "Error updating $image"
        done
    fi
    log_message "Pruning unused Docker volumes and images..."
    docker volume prune -f >/dev/null
    docker image prune -af >/dev/null
}

cleanup_and_exit() {
    if [ "$MODE" == "backup" ]; then
        start_docker_containers
    fi
    
    if mountpoint -q "$TEMPORARY_MOUNT_POINT"; then
        log_message "Unmounting network share..."
        umount "$TEMPORARY_MOUNT_POINT"
    fi
    
    if [ -d "$TEMPORARY_MOUNT_POINT" ]; then
        rmdir "$TEMPORARY_MOUNT_POINT"
    fi
    
    log_message "Script execution completed."
    exit
}

# --- Parse Arguments ---
# Added 'H:' to handle the hostname override flag
while getopts "m:p:f:H:c:" opt; do
    case "$opt" in
        m) MODE=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]') ;;
        p) PROTOCOL=$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]') ;;
        f) TAR_GZ_FILE="$OPTARG" ;;
        H) TARGET_HOSTNAME="$OPTARG" ;;
        c) CONFIG_FILE="$OPTARG" ;;
        *) usage ;;
    esac
done

# Validate basic mode/protocol parameters
if [[ "$MODE" != "backup" && "$MODE" != "restore" ]] || [[ "$PROTOCOL" != "cifs" && "$PROTOCOL" != "nfs" ]]; then
    usage
fi

# Ensure a filename is provided if we are restoring
if [[ "$MODE" == "restore" && -z "$TAR_GZ_FILE" ]]; then
    echo "Error: Restore mode requires a filename via the -f parameter."
    usage
fi

# --- Load Configuration File ---
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Configuration file not found at '$CONFIG_FILE'."
    exit 1
fi

# --- Main Script Logic ---
setup_logrotate
trap cleanup_and_exit SIGINT SIGTERM

log_message "=== Starting Unified Config/Param-Driven Script ==="
log_message "Local Hostname: $CURRENT_HOSTNAME"
log_message "Target Share Folder: $TARGET_HOSTNAME"

# 1. Create temporary mount point if missing
if [ ! -d "$TEMPORARY_MOUNT_POINT" ]; then
    mkdir -p "$TEMPORARY_MOUNT_POINT"
fi

# 2. Handle Network Mounting based on protocol
log_message "Mounting $PROTOCOL share..."
if [ "$PROTOCOL" == "cifs" ]; then
    mount -t cifs "//$CIFS_SERVER/$CIFS_SHARE" "$TEMPORARY_MOUNT_POINT" -o username="$CIFS_USERNAME",password="$CIFS_PASSWORD"
else
    mount -t nfs "$NFS_SERVER:$NFS_SHARE_PATH" "$TEMPORARY_MOUNT_POINT"
fi

if [ $? -ne 0 ]; then
    log_message "Failed to mount $PROTOCOL share. Check credentials and connectivity."
    exit 1
fi

# 3. Execute Mode Specific Actions
if [ "$MODE" == "backup" ]; then
    stop_docker_containers
    
    # Establish protocol specific target folder using the specified TARGET_HOSTNAME
    TARGET_FOLDER="$TEMPORARY_MOUNT_POINT/$TARGET_HOSTNAME"
    if [ ! -d "$TARGET_FOLDER" ]; then
        mkdir -p "$TARGET_FOLDER"
    fi
    
    BACKUP_FILENAME="${CURRENT_HOSTNAME}_DockerBackup_$(date +'%Y%m%d').tar.gz"
    log_message "Creating compressed backup archive..."
    tar -czvf "$TARGET_FOLDER/$BACKUP_FILENAME" "$LOCAL_FOLDER"
    
    if [ $? -eq 0 ]; then
        log_message "Backup successfully saved to $TARGET_FOLDER/$BACKUP_FILENAME"
    else
        log_message "Error: Backup creation failed."
    fi
    
    update_and_prune_docker

elif [ "$MODE" == "restore" ]; then
    # Look for the restore file inside the designated target folder or root mount depending on layout
    RESTORE_PATH="$TEMPORARY_MOUNT_POINT/$TARGET_HOSTNAME/$TAR_GZ_FILE"
    if [ ! -f "$RESTORE_PATH" ]; then
        RESTORE_PATH="$TEMPORARY_MOUNT_POINT/$TAR_GZ_FILE"
    fi

    if [ -f "$RESTORE_PATH" ]; then
        log_message "Found backup archive at $RESTORE_PATH. Decompressing..."
        tar -xzvf "$RESTORE_PATH" -C "$LOCAL_FOLDER"
        
        if [ $? -eq 0 ]; then
            log_message "Decompression completed successfully to $LOCAL_FOLDER"
            start_docker_containers
        else
            log_message "Error: Decompression failed."
        fi
    else
        log_message "Error: $TAR_GZ_FILE not found on the share (Checked paths: $TEMPORARY_MOUNT_POINT/$TARGET_HOSTNAME/ and root)."
    fi
fi

# 4. Cleanup and exit cleanly
cleanup_and_exit