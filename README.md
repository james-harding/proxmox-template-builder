# Proxmox-Template-Builder

Proxmox Template Builder is a bash script that automatically creates and maintains Virtual Machine (VM) templates in a Proxmox Virtual Environment (PVE) with Cloud-Init enabled. The templates are built from official cloud images of various Linux distributions like AlmaLinux, Debian, and Ubuntu, which have been minimally modified to install and enable the QEMU guest agent.

The script manages the lifecycle of templates by destroying and recreating templates that are older than a specified number of days (default: 5 days). This expiration period can be configured in the config.sh file. The script is designed to run as a scheduled task to maintain up-to-date templates consistently.

## Available Templates
- AlmaLinux 8
- AlmaLinux 9 
- Debian 11 
- Debian 12
- Fedora Cloud 39
- Fedora Cloud 40
- RockyLinux 8
- RockyLinux 9
- Ubuntu 22.04 
- Ubuntu 24.04

## Requirements

- Proxmox Virtual Environment (PVE) installed and configured
- `wget`, `curl`, and `libguestfs-tools` packages installed

## Getting Started

Clone the repository to your Proxmox host.
```
git clone https://github.com/james-harding/proxmox-template-builder.git
```

### General Configuration

The `config.sh` file contains configuration variables that control the behavior of the script, such as enabling/disabling specific templates and setting Cloud-Init options.

For example, to enable the Ubuntu 24.04 template, 
```
ubuntu_24_04_generic_enabled=true
```

For additional customization, each template has a separate configuration file in the `templates` directory, allowing you to modify template-specific settings.

### Cloud-Init Configuration

If using cloud-init, edit `config.sh` to provide authentication details to be able to login to your VM(s). 
```          
ci_user="demo"           # User name
ci_password="demo123!"   # Password to assign the user. Generally not recommended to define here. Use SSH keys instead.
ci_sshkeys=""            # Path to a file containing SSH public key(s). One key per line, OpenSSH format.
```

Other cloud-init configuration options can also be customised such as,
```
ci_nameserver=""                    # IP addresses of DNS servers to use (space separated). Uses host settings if not configured.
ci_searchdomain=""                  # DNS search domain. Uses host settings if not configured.
ci_ipconfig=""                      # IP addressing. Uses dhcp if not configured. 
```

### Running the Script

After updating the variables as needed, simply run the script.
```
./build-templates.sh
```
The script will create all templates that are enabled and recreate any old templates if present. 

### Optional: Add to Scheduler

To maintain always up-to-date templates, you may decide to run this script from a scheduler. For example, a basic cron job to run every Sunday at 1:30 AM. 

```
# Create/Update Proxmox VM Templates
30 1 * * 0 /path/to/proxmox-template-builder/build-templates.sh
```

---

## License

This project is licensed under the MIT license - See the LICENSE.md file for details.
