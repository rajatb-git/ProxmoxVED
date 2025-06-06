#!/usr/bin/env bash
source <(curl -s https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/build.func)
# Copyright (c) 2021-2025 tteck
# Author: tteck (tteckster)
# License: MIT | https://github.com/community-scripts/ProxmoxVED/raw/main/LICENSE
# Source: https://www.debian.org/

APP="Debian"
var_tags="${var_tags:-os}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-512}"
var_disk="${var_disk:-2}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"
var_fuse="${var_fuse:-yes}"
var_tun="${var_tun:-yes}"

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

read -p "Remove this Container? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
    pct stop "$CTID"
    pct destroy "$CTID"
    msg_ok "Removed this script"
else
    msg_warn "Did not remove this script"
fi
