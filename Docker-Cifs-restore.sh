#!/bin/bash

# Define your CIFS share credentials and mount options
CIFS_SHARE_USERNAME="your_username"
CIFS_SHARE_PASSWORD="your_password"
CIFS_SHARE_SERVER="your_cifs_server"
CIFS_SHARE_PATH="your_share_path"
TEMP_MOUNT_DIR="/mnt/temp_mount"
LOCAL_DECOMPRESS_DIR="/path/to/local_directory"

# Create the temporary mount directory if it doesn't exist
mkdir -p $TEMP_MOUNT_DIR

# Mount the CIFS share to the temporary directory
mount -t cifs //$CIFS_SHARE_SERVER/$CIFS_SHARE_PATH $TEMP_MOUNT_DIR -o username=$CIFS_SHARE_USERNAME,password=$CIFS_SHARE_PASSWORD

# Check if the mount was successful
if [ $? -eq 0 ]; then
    echo "CIFS share mounted successfully to $TEMP_MOUNT_DIR."

    # Define the name of the tar.gz file on the CIFS share
    TAR_GZ_FILE="example.tar.gz"

    # Check if the tar.gz file exists on the CIFS share
    if [ -f "$TEMP_MOUNT_DIR/$TAR_GZ_FILE" ]; then
        echo "Found $TAR_GZ_FILE on the CIFS share. Decompressing..."

        # Decompress the tar.gz file to the local directory
        tar -xzvf "$TEMP_MOUNT_DIR/$TAR_GZ_FILE" -C "$LOCAL_DECOMPRESS_DIR"

        # Check if the decompression was successful
        if [ $? -eq 0 ]; then
            echo "Decompression completed successfully to $LOCAL_DECOMPRESS_DIR."
        else
            echo "Error: Decompression failed."
        fi
    else
        echo "Error: $TAR_GZ_FILE not found on the CIFS share."
    fi

    # Unmount the CIFS share from the temporary directory
    umount $TEMP_MOUNT_DIR
    echo "CIFS share unmounted from $TEMP_MOUNT_DIR."
else
    echo "Error: CIFS share mount failed."
fi

# Remove the temporary mount directory
rmdir $TEMP_MOUNT_DIR
echo "Temporary mount directory removed."
