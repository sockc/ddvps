#!/usr/bin/env bash
set -Eeuo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
DDVPS_HOME="${DDVPS_HOME:-$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)}"

REPO="${REPO:-sockc/ddvps}"
BRANCH="${BRANCH:-main}"
UPSTREAM_REINSTALL_URL="${UPSTREAM_REINSTALL_URL:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
CORE="${CORE:-/root/reinstall.sh}"
LAST_CMD_SAFE="${LAST_CMD_SAFE:-/root/ddvps-last-command.txt}"
LAST_CMD_FULL="${LAST_CMD_FULL:-/root/ddvps-last-command.full}"

# shellcheck source=/dev/null
source "$DDVPS_HOME/data/distros.conf"
# shellcheck source=/dev/null
source "$DDVPS_HOME/data/windows.conf"
# shellcheck source=/dev/null
source "$DDVPS_HOME/lib/common.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/lib/detect.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/lib/safety.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/lib/input.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/lib/runner.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/menus/linux.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/menus/windows.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/menus/dd.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/menus/rescue.sh"
# shellcheck source=/dev/null
source "$DDVPS_HOME/menus/manage.sh"

main_menu() {
  need_root
  while true; do
    show_sysinfo
    echo "1. Linux 重装"
    echo "2. Windows 重装"
    echo "3. 自定义 RAW/VHD 镜像 DD"
    echo "4. 救援/手动引导"
    echo "5. 脚本管理"
    echo "0. 退出"
    echo
    read -r -p "请输入选项: " num
    case "$num" in
      1) linux_menu; pause ;;
      2) windows_menu; pause ;;
      3) dd_image_menu; pause ;;
      4) rescue_menu; pause ;;
      5) manage_menu; pause ;;
      0) exit 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

main_menu "$@"
