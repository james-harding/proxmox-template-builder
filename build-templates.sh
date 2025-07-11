#!/usr/bin/env bash

script_name="[Proxmox-Template-Builder]"
script_config="config.sh"

start_time=$(date +%s)

# Set colours for log messages
RED='\033[0;31m' 
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

# Load configuration variables
if [[ -r "$script_config" ]]; then
    source "$script_config"
else
    echo "$script_name ${RED}ERROR:${NC} Cannot read "$script_config"."
    exit 1
fi

# Store template configuration values
declare -A templates=(
    ["almalinux_8_generic"]="$almalinux_8_generic_enabled templates/almalinux-8-generic.vars"
    ["almalinux_9_generic"]="$almalinux_9_generic_enabled templates/almalinux-9-generic.vars"
    ["almalinux_10_generic"]="$almalinux_10_generic_enabled templates/almalinux-10-generic.vars"
    ["debian_11_generic"]="$debian_11_generic_enabled templates/debian-11-generic.vars"
    ["debian_12_generic"]="$debian_12_generic_enabled templates/debian-12-generic.vars"
    ["fedora_cloud_41_generic"]="$fedora_cloud_41_generic_enabled templates/fedora-cloud-41-generic.vars"
    ["fedora_cloud_42_generic"]="$fedora_cloud_42_generic_enabled templates/fedora-cloud-42-generic.vars"
    ["rockylinux_8_generic"]="$rockylinux_8_generic_enabled templates/rockylinux-8-generic.vars"
    ["rockylinux_9_generic"]="$rockylinux_9_generic_enabled templates/rockylinux-9-generic.vars"
    ["ubuntu_22_04_generic"]="$ubuntu_22_04_generic_enabled templates/ubuntu-22.04-generic.vars"
    ["ubuntu_24_04_generic"]="$ubuntu_24_04_generic_enabled templates/ubuntu-24.04-generic.vars"
)

check_packages() {
    local packages=("wget" "curl" "libguestfs-tools")
    local missing_packages=()

    for package in "${packages[@]}"; do
        if ! dpkg -s "$package" &> /dev/null; then
            missing_packages+=("$package")
        fi
    done

    if [ "${#missing_packages[@]}" -gt 0 ]; then
        echo -e "$script_name ${RED}ERROR:${NC} Required packages are not installed. Please install the following packages and try again."
        printf '  - %s\n' "${missing_packages[@]}"
        return 1
    fi
    return 0
}

check_template_expire() {
    vm_list=$(qm list | awk 'NR>1 {print $1}') 

    if echo "$vm_list" | grep -qw $template_vmid; then
        template_ctime=$(qm config $template_vmid | awk -F'[,=]' '/ctime/{print $4}')
        current_time=$(date +%s)
        template_age_secs=$((current_time - template_ctime))
        template_expire_secs=$((template_expire_days*24*60*60))

        if [ "$template_age_secs" -lt "$template_expire_secs" ]; then
            echo -e "$INFO_LOG_PREFIX ${GREEN}VM template $template_name is up-to-date.${NC}"
            template_expired=false
            return 0
        else
            echo "$WARNING_LOG_PREFIX VM template $template_name is older than $template_expire_days days and will be recreated."
            template_expired=true
        fi
    else
        echo "$INFO_LOG_PREFIX VM template $template_name does not exist and will be created."
        template_expired=true
    fi       
    return 0
}

download_cloud_image() {
    # Check if URL is valid
    response_code=$(curl -I -L -s -o /dev/null -w "%{http_code}" "$url")
    if [ "$response_code" -eq 200 ]; then
        cloud_image="$(basename "$url")"
        cloud_image_custom="$(echo "$cloud_image" | sed 's/\./\-custom\./')"
    else
        echo -e "$ERR_LOG_PREFIX Unable to download cloud image from "$url" ($response_code)."
        return 1
    fi

    # Check if download directory is writable
    if ! [ -w "$download_dir" ]; then
        echo -e "$ERR_LOG_PREFIX Failed to download cloud image. Unable to write to download directory."
        return 1
    fi

    # Only download cloud image if online source is newer
    if [ -f "$download_dir/$cloud_image" ]; then
        echo "$INFO_LOG_PREFIX Downloading cloud image..."
        if ! curl -L -z "$download_dir/$cloud_image" "$url" -o "$download_dir/$cloud_image"; then
            echo -e "$ERR_LOG_PREFIX Failed to download $url." >&2
            return 1
        fi
    else
        echo "$INFO_LOG_PREFIX Downloading cloud image..."
        if ! curl -L "$url" -o "$download_dir/$cloud_image"; then
            echo -e "$ERR_LOG_PREFIX Failed to download $url." >&2
            return 1
        fi
    fi
    
    echo "$INFO_LOG_PREFIX Successfully downloaded $cloud_image."
    return 0
}

customize_cloud_image() {
    cp $download_dir/$cloud_image $download_dir/$cloud_image_custom

    # Detect OS family and set update command
    os_update_cmd=""
    if virt-customize -a $download_dir/"$cloud_image_custom" --run-command 'test -f /etc/debian_version' &>/dev/null; then
        os_update_cmd="apt-get update"
    elif virt-customize -a $download_dir/"$cloud_image_custom" --run-command 'test -f /etc/redhat-release' &>/dev/null; then
        os_update_cmd="dnf makecache"
    fi

    if ! virt-customize -a $download_dir/"$cloud_image_custom" \
        ${os_update_cmd:+--run-command "$os_update_cmd"} \
        --install qemu-guest-agent \
        --run-command 'systemctl enable qemu-guest-agent.service'; then
        echo -e "$ERR_LOG_PREFIX Failed to customize cloud image." >&2
        return 1
    fi

    echo "$INFO_LOG_PREFIX Successfully customised $cloud_image."
    return 0
}

destroy_existing_vm() {
    vm_list=$(qm list | awk 'NR>1 {print $1}') 

    if echo "$vm_list" | grep -qw $template_vmid; then
        vms_in_pool=$(pvesh get /pools/Templates --noborder)
        if ! echo "$vms_in_pool" | grep -qw "qemu/$template_vmid"; then
            echo -e "$ERR_LOG_PREFIX Unable to destroy VM - Not in Resource Pool 'Templates'. Please destroy manually."
            return 1
        else
            echo "$INFO_LOG_PREFIX Destroying previous VM template..."
            if ! qm destroy $template_vmid --purge > /dev/null; then
                echo -e "$ERR_LOG_PREFIX Failed to destroy VM."
                return 1
            else
                echo "$INFO_LOG_PREFIX Successfully destroyed VM $template_vmid."
                return 0
            fi
        fi
    fi
}

create_pool() {
    local pool_name="Templates"

    # Check if the pool already exists
    existing_pools=$(pvesh get /pools --noborder)
    if echo "$existing_pools" | grep -qw "$pool_name"; then
        echo "$INFO_LOG_PREFIX Resource pool '$pool_name' already exists."
    else
        echo "$INFO_LOG_PREFIX Creating resource pool '$pool_name'..."
        if ! pvesh create /pools --pool "$pool_name" > /dev/null 2>&1; then
            echo -e "$ERR_LOG_PREFIX Failed to create resource pool '$pool_name'." >&2
            return 1
        fi
    fi
    return 0
}

create_vm_template () {
    local status=0

    create_pool
    if [ $? -ne 0 ]; then
        echo -e "$ERR_LOG_PREFIX Failed to create resource pool for templates." >&2
        return 1
    fi

    status=0
    create_vm=false
    echo "$INFO_LOG_PREFIX Creating VM..."
    
    while [ $status -eq 0 ]; do
        qm create $template_vmid --name "$template_name" > /dev/null || status=1

        if [ $status -eq 0 ]; then
            echo "$INFO_LOG_PREFIX Configuring VM hardware..."
            qm set $template_vmid --memory $template_memory --cores $template_cpu_cores --cpu cputype="$template_cpu_type" > /dev/null || status=1
            qm set $template_vmid --net0 $template_net_device,bridge=$template_net_bridge,firewall=$template_net_firewall > /dev/null || status=1
            if [ -n "$template_net_vlan_tag" ]; then
                qm set $template_vmid --net0 "$template_net_device,bridge=$template_net_bridge,firewall=$template_net_firewall,tag=$template_net_vlan_tag" > /dev/null || status=1
            fi

            echo "$INFO_LOG_PREFIX Importing customized cloud image and configuring VM storage..."
            qm set $template_vmid --scsihw virtio-scsi-single \
            --scsi0 "$template_pve_storage":0,import-from="$download_dir/$cloud_image_custom",iothread=1,discard="on",ssd=1 > /dev/null || status=1
            qm disk move $template_vmid scsi0 "$template_pve_storage" --format qcow2 --delete > /dev/null || status=1

            # add serial port to avoid serial-getty service failure on some images
            qm set $template_vmid --serial0 socket > /dev/null || status=1

            # resize VM disk (added check to only grow disk since shrinking is unsupported)
            cloud_image_virt_size_bytes=$(qemu-img info "$download_dir/$cloud_image_custom" | awk '/virtual size/ {print $5}' | sed 's/(//g')
            template_disk_size_bytes=$(($template_disk_size*1024**3))

            if [ $template_disk_size_bytes -gt $cloud_image_virt_size_bytes ]; then
                echo "$INFO_LOG_PREFIX Resizing boot disk..."
                qm resize $template_vmid scsi0 "$template_disk_size"G > /dev/null || status=1
            else
                echo -e "$WARN_LOG_PREFIX Shrinking disk is unsupported. Using cloud image virtual disk size."
            fi

            if [ "$ci_enabled" = true ]; then
                echo "$INFO_LOG_PREFIX Configuring cloud-init..."
                qm set $template_vmid --ide2 "$template_pve_storage":cloudinit > /dev/null || status=1
                if [ -n "$ci_user" ]; then 
                    qm set $template_vmid --ciuser "$ci_user" > /dev/null || status=1
                fi
                if [ -n "$ci_password" ]; then
                    qm set $template_vmid --cipassword "$ci_password" > /dev/null || status=1
                fi
                if [ -n "$ci_sshkeys" ]; then
                    qm set $template_vmid --sshkeys "$ci_sshkeys" > /dev/null || status=1
                fi
                if [ -n "$ci_nameserver" ]; then
                    qm set $template_vmid --nameserver "$ci_nameserver" > /dev/null || status=1
                fi
                if [ -n "$ci_searchdomain" ]; then 
                    qm set $template_vmid --searchdomain "$ci_searchdomain" > /dev/null || status=1
                fi
                qm set $template_vmid --ipconfig0 ip="dhcp" > /dev/null || status=1
            else
                echo -e "$WARN_LOG_PREFIX Cloud-Init is not enabled. Skipping configuration..."
            fi

            echo "$INFO_LOG_PREFIX Enabling qemu guest agent..."
            qm set $template_vmid --agent enabled=1 > /dev/null || status=1
        
            echo "$INFO_LOG_PREFIX Configuring remaining VM settings..."
            qm set $template_vmid --boot c --bootdisk scsi0 > /dev/null || status=1
            qm set $template_vmid --ostype=$template_os_type > /dev/null || status=1
            qm set $template_vmid --description "$template_description" > /dev/null || status=1

            create_vm=true
        fi

        if [ "$create_vm" = true ]; then
            break
        fi
    done

    if [ $status -eq 1 ]; then
        echo -e "$ERR_LOG_PREFIX Failed to create VM template."
        qm destroy $template_vmid > /dev/null
        echo "$INFO_LOG_PREFIX VM destroyed."
        return 1
    fi

    # Convert VM to template
    echo "$INFO_LOG_PREFIX Converting VM to template..."
    qm template $template_vmid > /dev/null

    # Add template to resource pool
    echo "$INFO_LOG_PREFIX Adding VM to resource pool 'Templates'..."
    pvesh set "/pools/Templates" -vms $template_vmid > /dev/null

    echo -e "$INFO_LOG_PREFIX ${GREEN}VM template ""$template_name"" successfully created.${NC}"
}

display_res() {
    local total_templates=$((success_count + failed_count))

    # Calculate script execution time
    end_time=$(date +%s)
    total_time=$((end_time - start_time))

    # Do not print results if no templates were processed
    if [ "$total_templates" -eq 0 ]; then
        return 0
    fi

    # Print job summary stats
    echo ""
    echo ""$script_name" - Job Results:"
    echo "-----------------------------------------"
    echo "Script execution time: $(printf '%dh:%dm:%ds' $((total_time/3600)) $((total_time%3600/60)) $((total_time%60)))"
    echo "Templates processed: $total_templates"
    echo -e "${GREEN}Templates created: $success_count ${NC}"
    echo -e "${RED}Templates failed: $failed_count ${NC}"

    # Print names of templates that failed to be created
    if [ "$failed_count" -gt 0 ]; then
        for template in "${!failed_templates[@]}"; do
            echo -e "${RED}   - $template (${failed_templates[$template]})${NC}"
        done
    fi
    return 0
}

clean_up() {
    if ! rm -f "$download_dir/$cloud_image_custom"; then
        echo -e "$ERR_LOG_PREFIX Unable to remove temp file "$download_dir/$cloud_image_custom"."
    else
        echo "$INFO_LOG_PREFIX Removed temporary custom image. Keeping original image."
    fi
}

### Main script execution ###

# Check if script is run with root permissions
if [ "$(id -u)" != "0" ]; then
    echo "$script_name ${RED}ERROR:${NC} This script must be run as root." 
    exit 1
fi

# Check if Proxmox is installed
if ! [ -f /etc/pve/pve-root-ca.pem ]; then
    echo "$script_name ${RED}ERROR:${NC} Proxmox is not installed, please run this script in a Proxmox Environment."
    exit 1
fi

# Check if required packages are installed
if ! check_packages; then
    exit 1
fi

# Check if any templates are enabled
any_templates_enabled=false
for template in "${!templates[@]}"; do
    read -r enabled _ <<< "${templates[$template]}"
    if [ "$enabled" = true ]; then
        any_templates_enabled=true
        break
    fi
done
if ! $any_templates_enabled; then
    echo -e "$script_name ${YELLOW}WARNING:${NC} No templates are enabled. Edit "$script_config" to enable VM templates."
    exit 0
fi

# Initialise counters to track success and failures when creating templates
success_count=0
failed_count=0
declare -A failed_templates

# Loop through templates array and create all enabled templates
for template in "${!templates[@]}"; do
    read -r enabled vars_file <<< "${templates[$template]}"
    if [ "$enabled" = true ]; then
        if [ -r "$vars_file" ]; then
            source "$vars_file"

            # Define logging prefixes to use in main functions
            INFO_LOG_PREFIX="$script_name $template_vmid INFO:"
            WARN_LOG_PREFIX="$script_name $template_vmid ${YELLOW}WARNING:${NC}"
            ERR_LOG_PREFIX="$script_name $template_vmid ${RED}ERROR:${NC}"
            
            # Recreate all enabled templates regardless of expiration time
            if [ "$template_force_recreate" = true ]; then
                echo -e "$WARN_LOG_PREFIX Forcing recreation of $template_name."
                image_ready=false
                if download_cloud_image; then
                    image_ready=true
                    if customize_cloud_image && destroy_existing_vm && create_vm_template; then
                        ((success_count++))
                    else
                        ((failed_count++))
                        failed_templates["$template_name"]="Failed"
                    fi
                else
                    ((failed_count++))
                    failed_templates["$template_name"]="Failed"
                fi
                $image_ready && clean_up
            else # Only recreate enabled templates if expiration time has been reached
                check_template_expire   
                if [ "$template_expired" = true ]; then
                    image_ready=false
                    if download_cloud_image; then
                        image_ready=true
                        if customize_cloud_image && destroy_existing_vm && create_vm_template; then
                            ((success_count++))
                        else
                            ((failed_count++))
                            failed_templates["$template_name"]="Failed"
                        fi
                    else
                        ((failed_count++))
                        failed_templates["$template_name"]="Failed"
                    fi
                    $image_ready && clean_up
                fi
            fi
        else
            echo -e "$script_name ${RED}ERROR:${NC} Unable to source $vars_file."
            ((failed_count++))
        fi      
    fi
done

# Print summary results
display_res

exit 0

