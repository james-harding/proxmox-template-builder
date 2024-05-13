#!/usr/bin/env bash

# Location to store cloud images
download_dir="/tmp"

### Template lifecycle configuration ###

template_expire_days=5          # Templates before expiry will not be recreated. (default=5d)
template_force_recreate=false   # If set to true, templates will always be recreated regardless of expiration time. (default=false)

### Cloud-Init configuration ###

ci_user="demo"                      # Set user name instead of the image's configured default user.                       
ci_password="demo123!"              # Not recommended to set password here - Use SSH keys instead.
ci_sshkeys="authorized_keys"        # File containing SSH public keys (one key per line, OpenSSH format).
#ci_nameserver=""                    # IP addresses of DNS servers to use (space separated). Uses host settings if not configured.
#ci_searchdomain=""                  # DNS search domain. Uses host settings if not configured.
ci_ipconfig=""                      # IP addressing. Uses dhcp if not configured. 

### Enable VM templates ###

# AlmaLinux versions
almalinux_8_9_generic_enabled=false
almalinux_9_4_generic_enabled=false

# Debian versions
debian_11_generic_enabled=false
debian_12_generic_enabled=false

# Fedora Cloud versions
fedora_cloud_39_generic_enabled=false
fedora_cloud_40_generic_enabled=false

# RockyLinux versions
rockylinux_8_generic_enabled=false
rockylinux_9_generic_enabled=false

# Ubuntu versions
ubuntu_22_04_generic_enabled=false
ubuntu_24_04_generic_enabled=false