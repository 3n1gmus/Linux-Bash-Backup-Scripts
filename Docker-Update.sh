#!/bin/bash

# Get the current hostname of the system
current_hostname=$(hostname)

# Define variables
log_file="/var/log/Docker_Backup.log"
max_log_files=5

# Function to check and add logrotate configuration
setup_logrotate() {
    local log_file="$1"
    logrotate_config="/etc/logrotate.d/$log_file"

    if [ ! -f "$logrotate_config" ]; then
        echo "Creating logrotate configuration for '$log_file'..."
        sudo tee "$logrotate_config" > /dev/null <<EOL
"/var/log/$log_file" {
    rotate 5
    daily
    compress
    missingok
    notifempty
}
EOL
        # Replace <your_username> and <your_group> with your actual username and group.
        echo "Logrotate configuration added for '$log_file'."
    else
        echo "Logrotate configuration for '$log_file' already exists."
    fi
}

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

# Function to log messages to the log file
log_message() {
    echo "$(date +'%Y-%m-%d %H:%M:%S') - $1" >> "$log_file"
}

# Function to clean up the temporary mount point and exit
cleanup_and_exit() {
    log_message "Starting Docker containers."
    start_docker_containers # Start any previously stopped Docker containers before exit
    log_message "Script execution completed."
    exit
}

# --- Script Start ---

# Setup Log rotation
setup_logrotate "$log_file"

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

# Unmount and clean up when done
cleanup_and_exit