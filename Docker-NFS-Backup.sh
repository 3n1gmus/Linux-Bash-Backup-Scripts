#!/bin/bash

# Function to stop all running Docker containers
stop_docker_containers() {
    echo "Stopping all running Docker containers..."
    docker stop $(docker ps -q)
}

# Function to start all previously stopped Docker containers
start_docker_containers() {
    echo "Starting previously stopped Docker containers..."
    docker start $(docker ps -a -q -f "status=exited")
}

# Function to update all Docker images
update_docker_images() {
    echo "Updating all Docker images..."
    docker pull $(docker images | grep -v 'REPOSITORY' | awk '{print $1}')
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

# Define variables for the NFS share
nfs_server="your_nfs_server"
nfs_share="/path/to/your_nfs_share"
nfs_folder="$current_hostname" # Use the hostname as the folder name on the share
local_folder="/path/to/my_local_folder"
temporary_mount_point="/mnt/temp_nfs_mount"
log_file="/var/log/mount_nfs_share.log"
max_log_files=5

# Function to log messages to the log file
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Function to clean up the temporary mount point and exit
cleanup_and_exit() {
    start_docker_containers # Start any previously stopped Docker containers before exit
    log_message "Unmounting the NFS share and cleaning up..."
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

# Prune unused Docker volumes and images
prune_docker_volumes
prune_docker_images
log_message "Unused Docker volumes and images pruned."

# Check if the temporary mount point already exists, if not, create it
if [ ! -d "$temporary_mount_point" ]; then
    log_message "Creating temporary mount point..."
    mkdir -p "$temporary_mount_point"
fi

# Mount the NFS share
log_message "Mounting NFS share..."
mount "$nfs_server:$nfs_share" "$temporary_mount_point"

# Check if the mount was successful
if [ $? -eq 0 ]; then
    log_message "NFS share mounted successfully at $temporary_mount_point"
else
    log_message "Failed to mount NFS share. Please check your NFS server and network connectivity."
    cleanup_and_exit
fi

# Check if the folder on the share exists, if not, create it
if [ ! -d "$temporary_mount_point/$nfs_folder" ]; then
    log_message "Creating folder '$nfs_folder' on the NFS share..."
    mkdir "$temporary_mount_point/$nfs_folder"
fi

# Create a backup of the local folder with the hostname and date in the filename, and compress it using gzip
backup_filename="${current_hostname}_$(date +'%Y%m%d').tar.gz"
log_message "Creating a backup of the local folder..."
tar -czvf "$temporary_mount_point/$nfs_folder/$backup_filename" "$local_folder"

if [ $? -eq 0 ]; then
    log_message "Backup created and stored on the NFS share at '$temporary_mount_point/$nfs_folder/$backup_filename'"
else
    log_message "Failed to create the backup. Please check the local folder path and permissions."
fi

# Perform log rotation
logrotate -s /tmp/logrotate_status --num "${max_log_files}" "$log_file"

# Start previously stopped Docker containers after backup
start_docker_containers
log_message "Docker containers started."

# Unmount and clean up when done
cleanup_and_exit
