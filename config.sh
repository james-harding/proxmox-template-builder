#!/usr/bin/env bash

# Location to store downloaded cloud images
download_dir="/tmp"

### Template lifecycle configuration ###

template_expire_days=5          # Templates before expiry will not be recreated. (default=5d)
template_force_recreate=false   # If set to true, templates will always be recreated regardless of expiration time. (default=false)

### Global cloud-init configuration ###

ci_user="demo"                      # Set user name instead of the image's configured default user.                       
ci_password="demo123!"              # Not recommended to set password here - Use SSH keys instead.
ci_sshkeys="authorized_keys"        # File containing SSH public keys (one key per line, OpenSSH format).
#ci_nameserver=""                    # IP addresses of DNS servers to use (space separated). Uses host settings if not configured.
#ci_searchdomain=""                  # DNS search domain. Uses host settings if not configured.
ci_ipconfig=""                      # IP addressing. Uses dhcp if not configured. 

### Enable required VM templates ###

# AlmaLinux 8.9 Generic
almalinux_8_9_generic_enabled=false
almalinux_8_9_generic_config="templates/almalinux-8.9-generic.vars"

# AlmaLinux 9.4 Generic
almalinux_9_4_generic_enabled=false
almalinux_9_4_generic_config="templates/almalinux-9.4-generic.vars"

# Debian 11 Generic (Bullseye)
debian_11_generic_enabled=false
debian_11_generic_config="templates/debian-11-generic.vars"

# Debian 12 Server (Bookworm)
debian_12_generic_enabled=false
debian_12_generic_config="templates/debian-12-generic.vars"

# Ubuntu 22.04 Server (Jammy Jellyfish)
ubuntu_22_04_generic_enabled=false
ubuntu_22_04_generic_config="templates/ubuntu-22.04-generic.vars"

# Ubuntu 24.04 Server (Noble Numbat)
ubuntu_24_04_generic_enabled=false
ubuntu_24_04_generic_config="templates/ubuntu-24.04-generic.vars"
