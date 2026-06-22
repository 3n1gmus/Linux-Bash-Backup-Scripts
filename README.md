```markdown
# Unified Docker Backup & Restore Utility Script

This repository contains a unified, production-ready Bash script that handles both **backups** and **restores** for your Docker environment data using either **CIFS/SMB** or **NFS** network storage protocols. 

Instead of juggling multiple scripts for different environments, this utility consolidates all logic into a single file driven by modular command-line flags and a distinct, secure configuration file.

## 🚀 Features
* **Unified Interface**: One script handles backups and restores across multiple protocols.
* **Smart Host Routing**: Backups are dynamically saved into a subfolder named after the host machine.
* **Cross-Host Restores**: Easily restore a backup from a different machine onto your current machine using host directory overrides.
* **Automated Retention Management**: Clears out old backups automatically using a configurable threshold variable (`RETENTION_DAYS`).
* **Docker Lifecycle Management**: Automatically stops containers before safe backup execution and safely spins them back up afterward.
* **Environment Maintenance**: Auto-pulls updated Docker images and prunes unused volumes/dangling layers post-backup.
* **Credential Isolation**: Keeps your storage passwords and endpoints separated cleanly in an external configuration file.
* **Automatic Log Management**: Provisions its own `logrotate` block to keep `/var/log` tidy.

---

## 🛠️ Configuration Setup

To keep your network credentials secure and separate from the script execution logic, the utility reads settings from a standalone configuration file.

1. Create a file named `docker_storage.conf` in the same directory as the script:
   ```bash
   touch docker_storage.conf
   chmod 600 docker_storage.conf

```

*(Note: Setting the permissions to `600` ensures only the file owner can read or write to it, safeguarding your plain-text passwords from other system users).*

2. Open the file and populate your respective storage network details:
```ini
# --- CIFS/SMB Configuration ---
CIFS_USERNAME="your_cifs_username"
CIFS_PASSWORD="your_cifs_password"
CIFS_SERVER="your_cifs_server_ip_or_hostname"
CIFS_SHARE="your_cifs_share_name"

# --- NFS Configuration ---
NFS_SERVER="your_nfs_server_ip_or_hostname"
NFS_SHARE_PATH="/path/to/your_nfs_share"

# --- Local Directory ---
LOCAL_FOLDER="/path/to/my_local_docker_folder"

# --- Retention Configuration ---
RETENTION_DAYS=14  # Keeps backups for 14 days, deletes anything older. Set to 0 to disable.

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

Ensure the script is marked as executable before running:

```bash
chmod +x docker-storage-util.sh

```

### 1. Backup Examples

During a backup, the script automatically builds a dynamic archive name formatted as `${HOSTNAME}_DockerBackup_YYYYMMDD.tar.gz`. It places it inside a host-specific subdirectory on your remote share. After completion, it will verify and automatically purge backups older than your configured `RETENTION_DAYS`.

* **Run a standard CIFS/SMB Backup:**
```bash
sudo ./docker-storage-util.sh -m backup -p cifs

```


* **Run a standard Network File System (NFS) Backup:**
```bash
sudo ./docker-storage-util.sh -m backup -p nfs

```


* **Force a backup into a custom directory path layout (e.g., matching a cluster name instead of the local machine hostname):**
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

---

## 🪵 Logging & Operations

The script writes verbose logs containing timestamps, execution modes, and protocol markers to:
`/var/log/Docker_Backup_Restore.log`

On its first run, it dynamically sets up a `logrotate` block inside `/etc/logrotate.d/` to prevent logs from over-allocating system space by rotating them daily and holding a maximum history of 5 archives.

```
