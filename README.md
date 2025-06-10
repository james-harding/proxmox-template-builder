# Proxmox-Template-Builder

Proxmox Template Builder is a bash script that automates the creation and maintenance of Virtual Machine (VM) templates in a Proxmox Virtual Environment (PVE) with Cloud-Init enabled.

The script manages the lifecycle of templates by destroying and recreating templates that are older than a specified number of days (default: 10 days). The script is intended to be run as a scheduled task to maintain up-to-date templates consistently, but can also be run ad-hoc. 

Once you have your template(s), you can use other automation tools such as Terraform and/or Ansible to provision and configure your VMs. Or just manually clone and configure them in Proxmox. 

## Available Templates

This tool will be actively maintained to provide up-to-date, ready-to-use templates for the latest two releases (current and previous) of popular Linux server distributions.

- [AlmaLinux](https://almalinux.org)
- [Debian](https://www.debian.org)
- [Fedora Cloud](https://fedoraproject.org/cloud/)
- [Rocky Linux](https://rockylinux.org)
- [Ubuntu Server](https://ubuntu.com/server)

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

Cloud-Init is enabled by default but can be disabled. If using cloud-init, edit `config.sh` to provide authentication details to be able to login to your VM(s). 
```          
ci_user="demo"           # User name
ci_password="demo123!"   # Password to assign the user. Generally not recommended to define here. Use SSH keys instead.
ci_sshkeys=""            # Path to a file containing SSH public key(s). One key per line, OpenSSH format.
```

### Running the Script

After updating the variables as needed, simply run the script.
```
./build-templates.sh
```
The script will create or update all templates that are enabled.

### Optional: Add to Scheduler

To maintain always up-to-date templates, you may decide to run this script from a scheduler. For example, a basic cron job to run every Sunday at 1:30 AM. 

```
# Create/Update Proxmox VM Templates
30 1 * * 0 /path/to/proxmox-template-builder/build-templates.sh
```

---

## License

This project is licensed under the MIT license - See the LICENSE.md file for details.
