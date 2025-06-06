#!/usr/bin/env bash
source <(curl -s https://git.community-scripts.org/rajatb-git/ProxmoxVED/raw/branch/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: bvdberg01
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/saltstack/salt

APP="saltmaster"
var_tags="${var_tags:-automations}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-1024}"
var_disk="${var_disk:-3}"
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

    if [[ ! -d /etc/salt ]]; then
        msg_error "No ${APP} Installation Found!"
        exit
    fi

    RELEASE=$(curl -fsSL https://api.github.com/repos/saltstack/salt/releases/latest | jq -r .tag_name | sed 's/^v//')
    if [[ ! -f /opt/${APP}_version.txt ]] || [[ "${RELEASE}" != "$(cat /opt/${APP}_version.txt)" ]]; then
        msg_info "Updating $APP to ${RELEASE}"
        sed -i "s/^\(Pin: version \).*/\1${RELEASE}/" /etc/apt/preferences.d/salt-pin-1001
        $STD apt-get update
        $STD apt-get upgrade -y
        echo "${RELEASE}" >/opt/${APP}_version.txt
        msg_ok "Updated ${APP} to ${RELEASE}"
    else
        msg_ok "${APP} is already up to date (${RELEASE})"
    fi
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
