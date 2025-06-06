#!/usr/bin/env bash
source <(curl -s https://git.rajatb-git.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/build.func)
# Copyright (c) 2021-2025 rajatb-git ORG
# Authors: MickLesk (CanbiZ)
# License: MIT | https://github.com/rajatb-git/ProxmoxVE/raw/main/LICENSE
# Source: https://frigate.video/

# App Default Values
APP="Frigate"
var_tags="${var_tags:-nvr}"
var_cpu="${var_cpu:-8}"
var_ram="${var_ram:-36864}"
var_disk="${var_disk:-2000}"
var_os="${var_os:-debian}"
var_version="${var_version:-11}"
var_unprivileged="${var_unprivileged:-0}"

echo "hello world"

# App Output
header_info "$APP"

# Core
variables
color
catch_errors

function update_script() {
    header_info
    check_container_storage
    check_container_resources
    if [[ ! -f /etc/systemd/system/frigate.service ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi
    msg_error "To update Frigate, create a new container and transfer your configuration."
    exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:5000${CL}"
