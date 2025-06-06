#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: MickLesk (CanbiZ)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE

source /dev/stdin <<<$(curl -fsSL https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/api.func)
source /dev/stdin <<<$(curl -fsSL https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/helpers.func)

function header_info {
    clear
    cat <<"EOF"
    ____       __    _                ______
   / __ \___  / /_  (_)___ _____     <  /__ \
  / / / / _ \/ __ \/ / __ `/ __ \    / /__/ /
 / /_/ /  __/ /_/ / / /_/ / / / /   / // __/
/_____/\___/_.___/_/\__,_/_/ /_/   /_//____/

EOF
}
header_info
echo -e "\n Loading..."
GEN_MAC=02:$(openssl rand -hex 5 | awk '{print toupper($0)}' | sed 's/\(..\)/\1:/g; s/.$//')
NEXTID=$(pvesh get /cluster/nextid)
RANDOM_UUID="$(cat /proc/sys/kernel/random/uuid)"
METHOD=""
NSAPP="debian12vm"
var_os="debian"
var_version="12"

colors

THIN="discard=on,ssd=1,"
set -e
trap 'error_handler $LINENO "$BASH_COMMAND"' ERR
trap cleanup EXIT
trap 'post_update_to_api "failed" "INTERRUPTED"' SIGINT
trap 'post_update_to_api "failed" "TERMINATED"' SIGTERM
function error_handler() {
    local exit_code="$?"
    local line_number="$1"
    local command="$2"
    local error_message="${RD}[ERROR]${CL} in line ${RD}$line_number${CL}: exit code ${RD}$exit_code${CL}: while executing command ${YW}$command${CL}"
    post_update_to_api "failed" "${command}"
    echo -e "\n$error_message\n"
    cleanup_vmid
}

function cleanup_vmid() {
    if qm status $VMID &>/dev/null; then
        qm stop $VMID &>/dev/null
        qm destroy $VMID &>/dev/null
    fi
}

function cleanup() {
    popd >/dev/null
    post_update_to_api "done" "none"
    rm -rf $TEMP_DIR
}

TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null
if whiptail --backtitle "Proxmox VE Helper Scripts" --title "Debian 12 VM" --yesno "This will create a New Debian 12 VM. Proceed?" 10 58; then
    :
else
    header_info && echo -e "${CROSS}${RD}User exited script${CL}\n" && exit
fi

function default_settings() {
    VMID="$NEXTID"
    FORMAT=",efitype=4m"
    MACHINE=""
    DISK_SIZE="8G"
    DISK_CACHE=""
    HN="debian"
    CPU_TYPE=""
    CORE_COUNT="2"
    RAM_SIZE="2048"
    BRG="vmbr0"
    MAC="$GEN_MAC"
    VLAN=""
    MTU=""
    START_VM="yes"
    METHOD="default"
    echo -e "${CONTAINERID}${BOLD}${DGN}Virtual Machine ID: ${BGN}${VMID}${CL}"
    echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}i440fx${CL}"
    echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}${DISK_SIZE}${CL}"
    echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}None${CL}"
    echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}${HN}${CL}"
    echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}KVM64${CL}"
    echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}${CORE_COUNT}${CL}"
    echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}${RAM_SIZE}${CL}"
    echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}${BRG}${CL}"
    echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}${MAC}${CL}"
    echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}Default${CL}"
    echo -e "${DEFAULT}${BOLD}${DGN}Interface MTU Size: ${BGN}Default${CL}"
    echo -e "${GATEWAY}${BOLD}${DGN}Start VM when completed: ${BGN}yes${CL}"
    echo -e "${CREATING}${BOLD}${DGN}Creating a Debian 12 VM using the above default settings${CL}"
}

function advanced_settings() {
    METHOD="advanced"
    while true; do
        if VMID=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Virtual Machine ID" 8 58 $NEXTID --title "VIRTUAL MACHINE ID" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
            if [ -z "$VMID" ]; then
                VMID="$NEXTID"
            fi
            if pct status "$VMID" &>/dev/null || qm status "$VMID" &>/dev/null; then
                echo -e "${CROSS}${RD} ID $VMID is already in use${CL}"
                sleep 2
                continue
            fi
            echo -e "${CONTAINERID}${BOLD}${DGN}Virtual Machine ID: ${BGN}$VMID${CL}"
            break
        else
            exit_script
        fi
    done

    if MACH=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "MACHINE TYPE" --radiolist --cancel-button Exit-Script "Choose Type" 10 58 2 \
        "i440fx" "Machine i440fx" ON \
        "q35" "Machine q35" OFF \
        3>&1 1>&2 2>&3); then
        if [ $MACH = q35 ]; then
            echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}$MACH${CL}"
            FORMAT=""
            MACHINE=" -machine q35"
        else
            echo -e "${CONTAINERTYPE}${BOLD}${DGN}Machine Type: ${BGN}$MACH${CL}"
            FORMAT=",efitype=4m"
            MACHINE=""
        fi
    else
        exit_script
    fi

    if DISK_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Disk Size in GiB (e.g., 10, 20)" 8 58 "$DISK_SIZE" --title "DISK SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        DISK_SIZE=$(echo "$DISK_SIZE" | tr -d ' ')
        if [[ "$DISK_SIZE" =~ ^[0-9]+$ ]]; then
            DISK_SIZE="${DISK_SIZE}G"
            echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}$DISK_SIZE${CL}"
        elif [[ "$DISK_SIZE" =~ ^[0-9]+G$ ]]; then
            echo -e "${DISKSIZE}${BOLD}${DGN}Disk Size: ${BGN}$DISK_SIZE${CL}"
        else
            echo -e "${DISKSIZE}${BOLD}${RD}Invalid Disk Size. Please use a number (e.g., 10 or 10G).${CL}"
            exit_script
        fi
    else
        exit_script
    fi

    if DISK_CACHE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "DISK CACHE" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
        "0" "None (Default)" ON \
        "1" "Write Through" OFF \
        3>&1 1>&2 2>&3); then
        if [ $DISK_CACHE = "1" ]; then
            echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}Write Through${CL}"
            DISK_CACHE="cache=writethrough,"
        else
            echo -e "${DISKSIZE}${BOLD}${DGN}Disk Cache: ${BGN}None${CL}"
            DISK_CACHE=""
        fi
    else
        exit_script
    fi

    if VM_NAME=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Hostname" 8 58 debian --title "HOSTNAME" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $VM_NAME ]; then
            HN="debian"
            echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
        else
            HN=$(echo ${VM_NAME,,} | tr -d ' ')
            echo -e "${HOSTNAME}${BOLD}${DGN}Hostname: ${BGN}$HN${CL}"
        fi
    else
        exit_script
    fi

    if CPU_TYPE1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "CPU MODEL" --radiolist "Choose" --cancel-button Exit-Script 10 58 2 \
        "0" "KVM64 (Default)" ON \
        "1" "Host" OFF \
        3>&1 1>&2 2>&3); then
        if [ $CPU_TYPE1 = "1" ]; then
            echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}Host${CL}"
            CPU_TYPE=" -cpu host"
        else
            echo -e "${OS}${BOLD}${DGN}CPU Model: ${BGN}KVM64${CL}"
            CPU_TYPE=""
        fi
    else
        exit_script
    fi

    if CORE_COUNT=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate CPU Cores" 8 58 2 --title "CORE COUNT" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $CORE_COUNT ]; then
            CORE_COUNT="2"
            echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
        else
            echo -e "${CPUCORE}${BOLD}${DGN}CPU Cores: ${BGN}$CORE_COUNT${CL}"
        fi
    else
        exit_script
    fi

    if RAM_SIZE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Allocate RAM in MiB" 8 58 2048 --title "RAM" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $RAM_SIZE ]; then
            RAM_SIZE="2048"
            echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}$RAM_SIZE${CL}"
        else
            echo -e "${RAMSIZE}${BOLD}${DGN}RAM Size: ${BGN}$RAM_SIZE${CL}"
        fi
    else
        exit_script
    fi

    if BRG=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Bridge" 8 58 vmbr0 --title "BRIDGE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $BRG ]; then
            BRG="vmbr0"
            echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
        else
            echo -e "${BRIDGE}${BOLD}${DGN}Bridge: ${BGN}$BRG${CL}"
        fi
    else
        exit_script
    fi

    if MAC1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a MAC Address" 8 58 $GEN_MAC --title "MAC ADDRESS" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $MAC1 ]; then
            MAC="$GEN_MAC"
            echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}$MAC${CL}"
        else
            MAC="$MAC1"
            echo -e "${MACADDRESS}${BOLD}${DGN}MAC Address: ${BGN}$MAC1${CL}"
        fi
    else
        exit_script
    fi

    if VLAN1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set a Vlan(leave blank for default)" 8 58 --title "VLAN" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $VLAN1 ]; then
            VLAN1="Default"
            VLAN=""
            echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}$VLAN1${CL}"
        else
            VLAN=",tag=$VLAN1"
            echo -e "${VLANTAG}${BOLD}${DGN}VLAN: ${BGN}$VLAN1${CL}"
        fi
    else
        exit_script
    fi

    if MTU1=$(whiptail --backtitle "Proxmox VE Helper Scripts" --inputbox "Set Interface MTU Size (leave blank for default)" 8 58 --title "MTU SIZE" --cancel-button Exit-Script 3>&1 1>&2 2>&3); then
        if [ -z $MTU1 ]; then
            MTU1="Default"
            MTU=""
            echo -e "${DEFAULT}${BOLD}${DGN}Interface MTU Size: ${BGN}$MTU1${CL}"
        else
            MTU=",mtu=$MTU1"
            echo -e "${DEFAULT}${BOLD}${DGN}Interface MTU Size: ${BGN}$MTU1${CL}"
        fi
    else
        exit_script
    fi

    if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "START VIRTUAL MACHINE" --yesno "Start VM when completed?" 10 58); then
        echo -e "${GATEWAY}${BOLD}${DGN}Start VM when completed: ${BGN}yes${CL}"
        START_VM="yes"
    else
        echo -e "${GATEWAY}${BOLD}${DGN}Start VM when completed: ${BGN}no${CL}"
        START_VM="no"
    fi

    if (whiptail --backtitle "Proxmox VE Helper Scripts" --title "ADVANCED SETTINGS COMPLETE" --yesno "Ready to create a Debian 12 VM?" --no-button Do-Over 10 58); then
        echo -e "${CREATING}${BOLD}${DGN}Creating a Debian 12 VM using the above advanced settings${CL}"
    else
        header_info
        echo -e "${ADVANCED}${BOLD}${RD}Using Advanced Settings${CL}"
        advanced_settings
    fi
}

root_check
arch_check
pve_check
ssh_check
start_script
post_to_api_vm

msg_info "Validating Storage"
while read -r line; do
    TAG=$(echo $line | awk '{print $1}')
    TYPE=$(echo $line | awk '{printf "%-10s", $2}')
    FREE=$(echo $line | numfmt --field 4-6 --from-unit=K --to=iec --format %.2f | awk '{printf( "%9sB", $6)}')
    ITEM="  Type: $TYPE Free: $FREE "
    OFFSET=2
    if [[ $((${#ITEM} + $OFFSET)) -gt ${MSG_MAX_LENGTH:-} ]]; then
        MSG_MAX_LENGTH=$((${#ITEM} + $OFFSET))
    fi
    STORAGE_MENU+=("$TAG" "$ITEM" "OFF")
done < <(pvesm status -content images | awk 'NR>1')
VALID=$(pvesm status -content images | awk 'NR>1')
if [ -z "$VALID" ]; then
    msg_error "Unable to detect a valid storage location."
    exit
elif [ $((${#STORAGE_MENU[@]} / 3)) -eq 1 ]; then
    STORAGE=${STORAGE_MENU[0]}
else
    while [ -z "${STORAGE:+x}" ]; do
        STORAGE=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Storage Pools" --radiolist \
            "Which storage pool you would like to use for ${HN}?\nTo make a selection, use the Spacebar.\n" \
            16 $(($MSG_MAX_LENGTH + 23)) 6 \
            "${STORAGE_MENU[@]}" 3>&1 1>&2 2>&3) || exit
    done
fi
msg_ok "Using ${CL}${BL}$STORAGE${CL} ${GN}for Storage Location."
msg_ok "Virtual Machine ID is ${CL}${BL}$VMID${CL}."
msg_info "Retrieving the URL for the Debian 12 Qcow2 Disk Image"
URL=https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-nocloud-amd64.qcow2
sleep 2
msg_ok "${CL}${BL}${URL}${CL}"
curl -fL --progress-bar "$URL" -O
echo -en "\e[1A\e[0K"
FILE=$(basename $URL)
msg_ok "Downloaded ${CL}${BL}${FILE}${CL}"

STORAGE_TYPE=$(pvesm status -storage $STORAGE | awk 'NR>1 {print $2}')
case $STORAGE_TYPE in
nfs | dir)
    DISK_EXT=".qcow2"
    DISK_REF="$VMID/"
    DISK_IMPORT="-format qcow2"
    THIN=""
    ;;
btrfs)
    DISK_EXT=".raw"
    DISK_REF="$VMID/"
    DISK_IMPORT="-format raw"
    FORMAT=",efitype=4m"
    THIN=""
    ;;
esac
for i in {0,1}; do
    disk="DISK$i"
    eval DISK${i}=vm-${VMID}-disk-${i}${DISK_EXT:-}
    eval DISK${i}_REF=${STORAGE}:${DISK_REF:-}${!disk}
done

msg_info "Creating a Debian 12 VM"
qm create $VMID -agent 1${MACHINE} -tablet 0 -localtime 1 -bios ovmf${CPU_TYPE} -cores $CORE_COUNT -memory $RAM_SIZE \
    -name $HN -tags community-script -net0 virtio,bridge=$BRG,macaddr=$MAC$VLAN$MTU -onboot 1 -ostype l26 -scsihw virtio-scsi-pci
pvesm alloc $STORAGE $VMID $DISK0 4M 1>&/dev/null
qm importdisk $VMID ${FILE} $STORAGE ${DISK_IMPORT:-} 1>&/dev/null
qm set $VMID \
    -efidisk0 ${DISK0_REF}${FORMAT} \
    -scsi0 ${DISK1_REF},${DISK_CACHE}${THIN}size=${DISK_SIZE} \
    -boot order=scsi0 \
    -serial0 socket >/dev/null
DESCRIPTION=$(
    cat <<EOF
<div align='center'>
  <a href='https://Helper-Scripts.com' target='_blank' rel='noopener noreferrer'>
    <img src='https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/images/logo-81x112.png' alt='Logo' style='width:81px;height:112px;'/>
  </a>

  <h2 style='font-size: 24px; margin: 20px 0;'>Debian VM</h2>

  <p style='margin: 16px 0;'>
    <a href='https://ko-fi.com/community_scripts' target='_blank' rel='noopener noreferrer'>
      <img src='https://img.shields.io/badge/&#x2615;-Buy us a coffee-blue' alt='spend Coffee' />
    </a>
  </p>

  <span style='margin: 0 10px;'>
    <i class="fa fa-github fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVE' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>GitHub</a>
  </span>
  <span style='margin: 0 10px;'>
    <i class="fa fa-comments fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVED/discussions' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Discussions</a>
  </span>
  <span style='margin: 0 10px;'>
    <i class="fa fa-exclamation-circle fa-fw" style="color: #f5f5f5;"></i>
    <a href='https://github.com/community-scripts/ProxmoxVED/issues' target='_blank' rel='noopener noreferrer' style='text-decoration: none; color: #00617f;'>Issues</a>
  </span>
</div>
EOF
)
qm set "$VMID" -description "$DESCRIPTION" >/dev/null
if [ -n "$DISK_SIZE" ]; then
    msg_info "Resizing disk to $DISK_SIZE GB"
    qm resize $VMID scsi0 ${DISK_SIZE} >/dev/null
else
    msg_info "Using default disk size of $DEFAULT_DISK_SIZE GB"
    qm resize $VMID scsi0 ${DEFAULT_DISK_SIZE} >/dev/null
fi

msg_ok "Created a Debian 12 VM ${CL}${BL}(${HN})"
if [ "$START_VM" == "yes" ]; then
    msg_info "Starting Debian 12 VM"
    qm start $VMID
    msg_ok "Started Debian 12 VM"
fi

msg_ok "Completed Successfully!\n"
echo "More Info at https://github.com/community-scripts/ProxmoxVED/discussions/836"
