#!/bin/bash

# Function to stop all running Docker containers
stop_docker_containers() {
    echo "Stopping all running Docker containers..."
    docker stop $(docker ps -q)
}

# Function to start all previously stopped Docker containers
start_docker_containers() {
    echo "Starting previously stopped Docker containers..."
    docker start $(docker ps -aq)
}

# Function to update all Docker images
update_docker_images() {
    local installed_images=$(docker images --format "{{.Repository}}")
    echo "List of currently installed images:"
    echo "$installed_images"
    echo

    if [ -n "$installed_images" ]; then
        for image in $installed_images; do
            echo "Updating $image..."
            docker pull "$image"
            if [ $? -eq 0 ]; then
                echo "$image successfully updated."
            else
                echo "Error updating $image."
            fi
            echo
        done
    else
        echo "No images found to update."
    fi
}

# Function to prune unused Docker volumes
prune_docker_volumes() {
    echo "Pruning unused Docker volumes..."
    docker volume prune -f
}

# Function to prune unused Docker images
prune_docker_images() {
    echo "Pruning unused Docker images..."
    docker image prune -af
}

# Get the current hostname of the system
current_hostname=$(hostname)

# Define variables for the CIFS share
cifs_username="your_cifs_username"
cifs_password="your_cifs_password"
cifs_server="your_cifs_server"
cifs_share="your_cifs_share_name"
cifs_folder="$current_hostname" # Use the hostname as the folder name on the share
local_folder="/path/to/my_local_folder"
temporary_mount_point="/mnt/temp_cifs_mount"
log_file="/var/log/mount_cifs_share.log"
max_log_files=5

# Function to log messages to the log file
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Function to clean up the temporary mount point and exit
cleanup_and_exit() {
    start_docker_containers # Start any previously stopped Docker containers before exit
    log_message "Unmounting the CIFS share and cleaning up..."
    umount "$temporary_mount_point"
    rmdir "$temporary_mount_point"
    log_message "Script execution completed."
    exit
}

# Trap signals to ensure proper cleanup before exiting
trap cleanup_and_exit SIGINT SIGTERM

log_message "=== Starting Backup Script ==="
log_message "Hostname: $current_hostname"

# Stop all running Docker containers before backup
stop_docker_containers
log_message "Docker containers stopped."

# Update all Docker images
update_docker_images
log_message "Docker images updated."

# Check if the temporary mount point already exists, if not, create it
if [ ! -d "$temporary_mount_point" ]; then
    log_message "Creating temporary mount point..."
    mkdir -p "$temporary_mount_point"
fi

# Mount the CIFS share
log_message "Mounting CIFS share..."
mount -t cifs "//$cifs_server/$cifs_share" "$temporary_mount_point" -o username="$cifs_username",password="$cifs_password"

# Check if the mount was successful
if [ $? -eq 0 ]; then
    log_message "CIFS share mounted successfully at $temporary_mount_point"
else
    log_message "Failed to mount CIFS share. Please check your credentials and network connectivity."
    cleanup_and_exit
fi

# Check if the folder on the share exists, if not, create it
if [ ! -d "$temporary_mount_point/$cifs_folder" ]; then
    log_message "Creating folder '$cifs_folder' on the CIFS share..."
    mkdir "$temporary_mount_point/$cifs_folder"
fi

# Create a backup of the local folder with the hostname and date in the filename, and compress it using gzip
backup_filename="${current_hostname}_DockerBackup_$(date +'%Y%m%d').tar.gz"
log_message "Creating a backup of the local folder..."
tar -czvf "$temporary_mount_point/$cifs_folder/$backup_filename" "$local_folder"

if [ $? -eq 0 ]; then
    log_message "Backup created and stored on the CIFS share at '$temporary_mount_point/$cifs_folder/$backup_filename'"
else
    log_message "Failed to create the backup. Please check the local folder path and permissions."
fi

# Prune unused Docker volumes and images
prune_docker_volumes
prune_docker_images
log_message "Unused Docker volumes and images pruned."

# Perform log rotation
logrotate -s /tmp/logrotate_status --num "${max_log_files}" "$log_file"

# Start previously stopped Docker containers after backup
start_docker_containers
log_message "Docker containers started."

# Unmount and clean up when done
cleanup_and_exit
