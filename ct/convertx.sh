#!/usr/bin/env bash
source <(curl -s https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: Omar Minaya
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/C4illin/ConvertX

APP="ConvertX"
var_tags="${var_tags:-converter}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-4096}"
var_disk="${var_disk:-20}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -d /var ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_info "Updating $APP LXC"
    RELEASE=$(curl -fsSL https://api.github.com/repos/C4illin/ConvertX/releases/latest | jq -r .tag_name | sed 's/^v//')
    curl -fsSL -o "/opt/convertx/ConvertX-${RELEASE}.tar.gz" "https://github.com/C4illin/ConvertX/archive/refs/tags/v${RELEASE}.tar.gz"
    tar --strip-components=1 -xf "/opt/convertx/ConvertX-${RELEASE}.tar.gz" -C /opt/convertx
    cd /opt/convertx
    bun update

    $STD systemctl restart convertx
    $STD apt-get update
    $STD apt-get -y upgrade
    msg_ok "Updated $APP LXC"
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:3000${CL}"
