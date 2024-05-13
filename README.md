# Proxmox-Template-Builder

A simple bash script to automatically build Virtual Machine (VM) templates in Proxmox Virtual Environment (PVE) with Cloud-Init support.

## Available Templates
- AlmaLinux 8.9 (Midnight Oncilla)
- AlmaLinux 9.4 (Seafoam Ocelot)
- Debian 11 (Bullseye)
- Debian 12 (Bookworm)
- Ubuntu 22.04 (Jammy Jellyfish)
- Ubuntu 24.04 (Noble Numbat)

## Getting Started

Clone the repository
```
git clone https://github.com/james-harding/pve-template-builder.git
```

Ensure required packages are installed
```
sudo apt install wget curl libguestfs-tools
```

wget and curl should already be installed but `libguestfs-tools` will likely need to be installed.

---

### Selecting Templates

Edit `config.sh` to enable or disable specific VM templates.

For example, to enable the Ubuntu 24.04 template, 
```
ubuntu_24_04_generic_enabled=true
```

For additional customisation, each template has a separate configuration file in the `templates` directory.

---

### Cloud-Init Configuration

Edit `config.sh` and provide values for the following variables
```
ci_user="demo"                      # User name                                       
ci_password="demo"                  # Password to assign the user. Generally not recommended. Use SSH keys instead.           
ci_sshkeys="authorized_keys"        # Inject public SSH keys (one key per line, OpenSSH format.) 
```

---

### Running the Script

After updating the variables, simply run the script.

```
./build-templates.sh
```
Depending on how many templates are enabled, you should see a number of templates appear in the Proxmox interface.

---

### Optional: Add to scheduler

To maintain always up-to-date templates, run this script from a scheduler. For example, a basic cron job to run every Sunday at 1:30 AM. 

```
# Create/Update Proxmox VM Templates
30 1 * * 0 /path/to/proxmox-template-builder/build-templates.sh
```

---

## License

This project is licensed under the MIT license - See the LICENSE.md file for details.