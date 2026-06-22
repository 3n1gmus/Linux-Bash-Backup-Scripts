```markdown
## Docker Backup & Restore Utility Script

This repository contains a unified, production-ready Bash script that handles both **backups** and **restores** for your Docker environment data using either **CIFS/SMB** or **NFS** network storage protocols. 

It streamlines your disaster recovery process by automatically managing the lifecycle of your Docker containers during maintenance tasks, keeping localized application logs via `logrotate`, and optimizing your environment through automated image and volume clean-ups.

### 🚀 Features
* **Unified Interface**: One script handles backups and restores across multiple protocols.
* **Smart Host Routing**: Backups are dynamically saved into a subfolder named after the host machine.
* **Cross-Host Restores**: Easily restore a backup from a different machine onto your current machine using hostname overrides.
* **Docker Lifecycle Management**: Automatically stops containers before safe backup execution and safely spins them back up afterward.
* **Environment Maintenance**: Auto-pulls updated Docker images and prunes unused volumes/dangling layers post-backup.
* **Credential Isolation**: Keeps your storage passwords and endpoints separated cleanly in an external configuration file.
* **Automatic Log Management**: Provisions its own `logrotate` block to keep `/var/log` tidy.

---

## 🛠️ Configuration Setup

To keep your network credentials secure and separate from the logic, the script utilizes a standalone configuration file. 

1. Create a file named `docker_storage.conf` in the same directory as the script:
   ```bash
   touch docker_storage.conf
   chmod 600 docker_storage.conf

```

*(Note: Setting the permissions to `600` ensures only the file owner can read or write to it, safeguarding your plain-text passwords).*

2. Open the file and populate your respective server details:
```ini
# --- CIFS/SMB Configuration ---
CIFS_USERNAME="your_cifs_username"
CIFS_PASSWORD="your_cifs_password"
CIFS_SERVER="your_cifs_server"
CIFS_SHARE="your_cifs_share_name"

# --- NFS Configuration ---
NFS_SERVER="your_nfs_server"
NFS_SHARE_PATH="/path/to/your_nfs_share"

# --- Local Directory ---
LOCAL_FOLDER="/path/to/my_local_folder"

```



---

## 📖 Usage & Syntax

The script relies on standard command-line flags (`getopts`) for dynamic runtime execution.

```bash
sudo ./docker-storage-util.sh -m <mode> -p <protocol> [-f <filename>] [-H <target_hostname>] [-c <config_path>]

```

### Parameters:

| Flag | Name | Description | Requirement |
| --- | --- | --- | --- |
| **`-m`** | Mode | Defines execution type: `backup` or `restore` | **Required** |
| **`-p`** | Protocol | Defines the network storage protocol: `cifs` or `nfs` | **Required** |
| **`-f`** | Filename | The specific `.tar.gz` file name to extract from storage | **Required for Restore only** |
| **`-H`** | Hostname | Overrides the host subdirectory to check on the share | Optional (Defaults to local system hostname) |
| **`-c`** | Config Path | Path to custom configuration file | Optional (Defaults to `./docker_storage.conf`) |

---

## 💡 Code Examples

Ensure the script is executable before running:

```bash
chmod +x docker-storage-util.sh

```

### 1. Backup Examples

During a backup, the script automatically builds a dynamic archive name formatted as `${HOSTNAME}_DockerBackup_YYYYMMDD.tar.gz`. It places it inside a host-specific subdirectory on your remote share.

* **Run a standard CIFS/SMB Backup:**
```bash
sudo ./docker-storage-util.sh -m backup -p cifs

```


* **Run a Backup and force it into a custom folder layout (e.g., matching a cluster name):**
```bash
sudo ./docker-storage-util.sh -m backup -p nfs -H MyClusterName

```



### 2. Restore Examples

To restore, look up your target archive filename on your network share storage, specify it at execution time using the `-f` flag, and let the script safely mount and unpack the data back into your configured `LOCAL_FOLDER`.

* **Standard Native Restore (Restoring a backup made by the current machine):**
```bash
sudo ./docker-storage-util.sh -m restore -p cifs -f compass_DockerBackup_20260622.tar.gz

```


* **Cross-Host Restore (Restoring a backup file belonging to a *different* machine, e.g., restoring `Charlo`'s backup onto the `compass` machine):**
```bash
sudo ./docker-storage-util.sh -m restore -p cifs -f Charlo_DockerBackup_20260610.tar.gz -H Charlo

```



### 3. Custom Configuration Path Example

If you host your configuration file securely elsewhere in the file system (e.g., `/etc/`), call it explicitly:

```bash
sudo ./docker-storage-util.sh -m backup -p nfs -c /etc/docker_storage.conf

```
