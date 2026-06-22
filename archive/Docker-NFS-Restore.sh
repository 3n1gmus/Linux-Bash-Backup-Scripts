#!/bin/bash

# Define your NFS share and mount options
NFS_SERVER="your_nfs_server"
NFS_SHARE_PATH="your_nfs_share_path"
TEMP_MOUNT_DIR="/mnt/temp_mount"
LOCAL_DECOMPRESS_DIR="/path/to/local_directory"

# Create the temporary mount directory if it doesn't exist
mkdir -p $TEMP_MOUNT_DIR

# Mount the NFS share to the temporary directory
mount -t nfs $NFS_SERVER:$NFS_SHARE_PATH $TEMP_MOUNT_DIR

# Check if the mount was successful
if [ $? -eq 0 ]; then
    echo "NFS share mounted successfully to $TEMP_MOUNT_DIR."

    # Define the name of the tar.gz file on the NFS share
    TAR_GZ_FILE="example.tar.gz"

    # Check if the tar.gz file exists on the NFS share
    if [ -f "$TEMP_MOUNT_DIR/$TAR_GZ_FILE" ]; then
        echo "Found $TAR_GZ_FILE on the NFS share. Decompressing..."

        # Decompress the tar.gz file to the local directory
        tar -xzvf "$TEMP_MOUNT_DIR/$TAR_GZ_FILE" -C "$LOCAL_DECOMPRESS_DIR"

        # Check if the decompression was successful
        if [ $? -eq 0 ]; then
            echo "Decompression completed successfully to $LOCAL_DECOMPRESS_DIR."
        else
            echo "Error: Decompression failed."
        fi
    else
        echo "Error: $TAR_GZ_FILE not found on the NFS share."
    fi

    # Unmount the NFS share from the temporary directory
    umount $TEMP_MOUNT_DIR
    echo "NFS share unmounted from $TEMP_MOUNT_DIR."
else
    echo "Error: NFS share mount failed."
fi

# Remove the temporary mount directory
rmdir $TEMP_MOUNT_DIR
echo "Temporary mount directory removed."
