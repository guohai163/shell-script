#!/bin/sh
#
# 脚本的作用是在debian/ubuntu系统上一键安装NAS环境
# =====================================================

# Define your own values for these variables
# - TOOLS_INSTALL_PATH 所有工具的安装目录

TOOLS_INSTALL_PATH='/opt'

# =====================================================
exiterr() { echo "Error: $1" >&2; exit 1; }

check_root() {
  if [ "$(id -u)" != 0 ]; then
    exiterr "Script must be run as root. Try 'sudo sh $0'"
  fi
}

check_os() {
    os_type=$(lsb_release -si 2>/dev/null)
    [ -z "$os_type" ] && [ -f /etc/os-release ] && os_type=$(. /etc/os-release && printf '%s' "$ID")
    case $os_type in
        [Uu]buntu)
            os_type=ubuntu
            ;;
        [Dd]ebian|[Kk]ali)
            os_type=debian
            ;;
        *)
cat 1>&2 <<'EOF'
Error: This script only supports one of the following OS:
       Ubuntu, Debian
EOF
            exit 1
            ;;
    esac
}

wait_for_apt() {
  count=0
  apt_lk=/var/lib/apt/lists/lock
  pkg_lk=/var/lib/dpkg/lock
  while fuser "$apt_lk" "$pkg_lk" >/dev/null 2>&1 \
    || lsof "$apt_lk" >/dev/null 2>&1 || lsof "$pkg_lk" >/dev/null 2>&1; do
    [ "$count" = 0 ] && echo "## Waiting for apt to be available..."
    [ "$count" -ge 100 ] && exiterr "Could not get apt/dpkg lock."
    count=$((count+1))
    printf '%s' '.'
    sleep 3
  done
}

install_base_tools() {
    wait_for_apt
    export DEBIAN_FRONTEND=noninteractive
      (
        set -x
        apt-get -yqq update 
      ) || exiterr "'apt-get update' failed."
      (
        set -x
        apt-get -yqq install curl vim smartmontools ca-certificates >/dev/null
      ) || exiterr "'apt-get install base tools' failed."
}

install_webmin() {
    echo 'install webmin'
    curl -o webmin-setup-repos.sh https://raw.githubusercontent.com/webmin/webmin/master/webmin-setup-repos.sh
    sh webmin-setup-repos.sh -f
    wait_for_apt
    export DEBIAN_FRONTEND=noninteractive
      (
        set -x
        apt-get -yqq install webmin >/dev/null
      ) || exiterr "'apt-get install webmin' failed."
}

install_docker() {
    echo 'install docker'
    install -m 0755 -d /etc/apt/keyrings
    case $os_type in
        [Uu]buntu)
            curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
            ;;
        [Dd]ebian|[Kk]ali)
            curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
            chmod a+r /etc/apt/keyrings/docker.asc
            echo \
                "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
                $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
                tee /etc/apt/sources.list.d/docker.list > /dev/null
            ;;
    esac
    

    chmod a+r /etc/apt/keyrings/docker.asc
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    wait_for_apt
    export DEBIAN_FRONTEND=noninteractive
    (
        set -x
        apt-get -yqq update
    ) || exiterr "'apt-get update' failed."
    export DEBIAN_FRONTEND=noninteractive
    (
        set -x
        apt-get -yqq install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null
    ) || exiterr "'apt-get install docker' failed."
}

run_install() {
    status=0
    echo "install over! use webbrower open http://<Your-Nas-IP>"
}

nas_setup() {
  check_root
  check_os
  install_base_tools
  install_webmin
  install_docker
  run_install
}

## Defer setup until we have the complete script
nas_setup "$@"

exit "$status"