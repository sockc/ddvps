#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-sockc/ddvps}"
BRANCH="${BRANCH:-main}"

UPSTREAM_REINSTALL_URL="${UPSTREAM_REINSTALL_URL:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
CORE="/tmp/reinstall.sh"
LAST_CMD="/root/ddvps-last-command.txt"

RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
PLAIN='\033[0m'

info() { echo -e "${GREEN}$*${PLAIN}"; }
warn() { echo -e "${YELLOW}$*${PLAIN}"; }
err()  { echo -e "${RED}$*${PLAIN}"; }

pause() {
  echo
  read -r -p "按回车返回菜单..."
}

need_root() {
  if [ "$(id -u)" != "0" ]; then
    err "请使用 root 用户运行。"
    exit 1
  fi
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

download_core() {
  info "正在下载原版 reinstall.sh ..."
  rm -f "$CORE"

  if has_cmd curl; then
    curl -L --connect-timeout 10 --retry 2 -o "$CORE" "$UPSTREAM_REINSTALL_URL"
  elif has_cmd wget; then
    wget -O "$CORE" "$UPSTREAM_REINSTALL_URL"
  else
    err "未找到 curl 或 wget，无法下载 reinstall.sh"
    exit 1
  fi

  chmod +x "$CORE"

  if [ ! -s "$CORE" ]; then
    err "reinstall.sh 下载失败或文件为空。"
    exit 1
  fi
}

show_sysinfo() {
  clear
  echo -e "${BLUE}========== DDVPS 重装增强菜单 ==========${PLAIN}"
  echo "仓库   : $REPO"
  echo "分支   : $BRANCH"
  echo "核心   : bin456789/reinstall"
  echo

  echo -e "${BLUE}========== 当前机器信息 ==========${PLAIN}"
  echo "主机名 : $(hostname 2>/dev/null || echo unknown)"
  echo "系统   : $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2- | tr -d '"' || echo unknown)"
  echo "架构   : $(uname -m)"
  echo "内核   : $(uname -r)"

  if has_cmd systemd-detect-virt; then
    echo "虚拟化 : $(systemd-detect-virt 2>/dev/null || echo none)"
  else
    echo "虚拟化 : unknown"
  fi

  echo "内存   : $(free -h 2>/dev/null | awk '/Mem:/ {print $2}' || echo unknown)"
  echo "硬盘   :"
  lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print "         /dev/"$1" "$2}' || true

  echo "公网IP : $(curl -4 -s --connect-timeout 3 https://api.ipify.org 2>/dev/null || echo unknown)"
  echo
}

check_virt_warning() {
  local virt=""
  if has_cmd systemd-detect-virt; then
    virt="$(systemd-detect-virt 2>/dev/null || true)"
  fi

  if [ "$virt" = "openvz" ] || [ "$virt" = "lxc" ] || [ -d /proc/vz ]; then
    warn "检测到可能是 OpenVZ/LXC 环境。"
    warn "这类容器环境通常不适合 DD/重装系统，建议不要继续。"
    echo
    read -r -p "仍要继续？输入 YES 继续，其它返回: " x
    [ "$x" = "YES" ] || return 1
  fi

  return 0
}

confirm_danger() {
  echo
  err "危险操作：该操作可能清空当前 VPS 整个硬盘。"
  err "请确保你有控制台/VNC/救援模式，并且已经备份重要数据。"
  echo
  read -r -p "请输入 YES 确认继续: " yes
  [ "$yes" = "YES" ] || {
    warn "已取消。"
    return 1
  }
  return 0
}

ask_common_linux_opts() {
  COMMON_ARGS=()

  echo
  read -r -p "SSH 端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  COMMON_ARGS+=(--ssh-port "$ssh_port")

  echo
  read -r -p "Web 观察端口 [默认不设置]: " web_port
  if [ -n "$web_port" ]; then
    COMMON_ARGS+=(--web-port "$web_port")
  fi

  echo
  read -r -p "是否设置 root 密码？[y/N]: " set_pass
  if [[ "$set_pass" =~ ^[Yy]$ ]]; then
    read -r -s -p "请输入 root 密码: " root_pass
    echo
    if [ -n "$root_pass" ]; then
      COMMON_ARGS+=(--password "$root_pass")
    fi
  fi

  echo
  read -r -p "是否导入 SSH 公钥？[y/N]: " set_key
  if [[ "$set_key" =~ ^[Yy]$ ]]; then
    read -r -p "粘贴 SSH 公钥: " ssh_key
    if [ -n "$ssh_key" ]; then
      COMMON_ARGS+=(--ssh-key "$ssh_key")
    fi
  fi

  echo
  read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
  if [ -n "$frpc_config" ]; then
    COMMON_ARGS+=(--frpc-config "$frpc_config")
  fi

  echo
  echo "hold 模式："
  echo "0. 不使用"
  echo "1. 只进入安装环境，先验证网络"
  echo "2. 安装完成后不自动重启，方便检查"
  read -r -p "请选择 [0-2，默认 0]: " hold_mode
  hold_mode="${hold_mode:-0}"

  case "$hold_mode" in
    1) COMMON_ARGS+=(--hold 1) ;;
    2) COMMON_ARGS+=(--hold 2) ;;
  esac
}

ask_dd_opts() {
  DD_ARGS=()

  echo
  read -r -p "SSH 观察端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  DD_ARGS+=(--ssh-port "$ssh_port")

  read -r -p "Web 观察端口 [默认不设置]: " web_port
  if [ -n "$web_port" ]; then
    DD_ARGS+=(--web-port "$web_port")
  fi

  read -r -p "cloud-init NoCloud 目录或 URL [默认不设置]: " cloud_data
  if [ -n "$cloud_data" ]; then
    DD_ARGS+=(--cloud-data "$cloud_data")
  fi

  echo
  echo "hold 模式："
  echo "0. 不使用"
  echo "1. 只进入安装环境，先验证网络"
  echo "2. DD 完成后不自动重启"
  read -r -p "请选择 [0-2，默认 0]: " hold_mode
  hold_mode="${hold_mode:-0}"

  case "$hold_mode" in
    1) DD_ARGS+=(--hold 1) ;;
    2) DD_ARGS+=(--hold 2) ;;
  esac
}

save_cmd() {
  {
    echo "# 生成时间: $(date '+%F %T')"
    printf "bash %q " "$CORE"
    printf "%q " "$@"
    echo
  } > "$LAST_CMD"

  info "命令已保存到: $LAST_CMD"
}

run_or_print() {
  local args=("$@")

  echo
  echo -e "${BLUE}即将执行命令：${PLAIN}"
  printf "bash %q " "$CORE"
  printf "%q " "${args[@]}"
  echo
  echo

  save_cmd "${args[@]}"

  echo "1. 立即执行"
  echo "2. 只生成命令，不执行"
  echo "0. 取消"
  read -r -p "请选择 [0-2]: " act

  case "$act" in
    1)
      confirm_danger || return 0
      download_core
      info "开始执行 reinstall..."
      bash "$CORE" "${args[@]}"
      ;;
    2)
      info "已生成命令，不执行。"
      ;;
    *)
      warn "已取消。"
      ;;
  esac
}

install_linux() {
  local distro="$1"
  local version="${2:-}"
  shift 2 || true

  check_virt_warning || return 0
  ask_common_linux_opts

  local args=("$distro")
  if [ -n "$version" ]; then
    args+=("$version")
  fi

  while [ "$#" -gt 0 ]; do
    args+=("$1")
    shift
  done

  args+=("${COMMON_ARGS[@]}")
  run_or_print "${args[@]}"
}

alpine_live() {
  check_virt_warning || return 0

  COMMON_ARGS=()
  echo
  read -r -p "SSH 端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  COMMON_ARGS+=(--ssh-port "$ssh_port")

  read -r -p "是否设置临时 root 密码？[y/N]: " set_pass
  if [[ "$set_pass" =~ ^[Yy]$ ]]; then
    read -r -s -p "请输入密码: " root_pass
    echo
    [ -n "$root_pass" ] && COMMON_ARGS+=(--password "$root_pass")
  fi

  read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
  [ -n "$frpc_config" ] && COMMON_ARGS+=(--frpc-config "$frpc_config")

  run_or_print alpine --hold 1 "${COMMON_ARGS[@]}"
}

netboot_menu() {
  check_virt_warning || return 0
  run_or_print netboot.xyz
}

dd_custom_image() {
  check_virt_warning || return 0

  echo
  read -r -p "请输入 RAW/VHD 镜像 URL: " img_url
  if [ -z "$img_url" ]; then
    err "镜像 URL 不能为空。"
    return 0
  fi

  ask_dd_opts
  run_or_print dd --img "$img_url" "${DD_ARGS[@]}"
}

windows_auto() {
  check_virt_warning || return 0

  echo
  read -r -p "Windows 镜像名称 [默认: Windows 11 Enterprise LTSC 2024]: " image_name
  image_name="${image_name:-Windows 11 Enterprise LTSC 2024}"

  read -r -p "语言 [默认: zh-cn，可填 zh-tw/en-us]: " lang
  lang="${lang:-zh-cn}"

  COMMON_ARGS=()
  read -r -s -p "Administrator 密码 [留空由原脚本随机]: " win_pass
  echo
  [ -n "$win_pass" ] && COMMON_ARGS+=(--password "$win_pass")

  read -r -p "RDP 端口 [默认 3389，不修改则留空]: " rdp_port
  [ -n "$rdp_port" ] && COMMON_ARGS+=(--rdp-port "$rdp_port")

  read -r -p "是否允许 Ping？[y/N]: " allow_ping
  [[ "$allow_ping" =~ ^[Yy]$ ]] && COMMON_ARGS+=(--allow-ping)

  run_or_print windows --image-name "$image_name" --lang "$lang" "${COMMON_ARGS[@]}"
}

windows_custom_iso() {
  check_virt_warning || return 0

  echo
  read -r -p "Windows 镜像名称: " image_name
  read -r -p "ISO URL: " iso_url

  if [ -z "$image_name" ] || [ -z "$iso_url" ]; then
    err "镜像名称和 ISO URL 不能为空。"
    return 0
  fi

  COMMON_ARGS=()
  read -r -s -p "Administrator 密码 [留空由原脚本随机]: " win_pass
  echo
  [ -n "$win_pass" ] && COMMON_ARGS+=(--password "$win_pass")

  read -r -p "RDP 端口 [默认 3389，不修改则留空]: " rdp_port
  [ -n "$rdp_port" ] && COMMON_ARGS+=(--rdp-port "$rdp_port")

  read -r -p "是否允许 Ping？[y/N]: " allow_ping
  [[ "$allow_ping" =~ ^[Yy]$ ]] && COMMON_ARGS+=(--allow-ping)

  run_or_print windows --image-name "$image_name" --iso "$iso_url" "${COMMON_ARGS[@]}"
}

reset_reinstall() {
  download_core
  echo
  warn "此功能用于在重启前取消误执行的 reinstall 操作。"
  read -r -p "确认执行 reset？输入 YES: " yes
  if [ "$yes" = "YES" ]; then
    bash "$CORE" reset
  else
    warn "已取消。"
  fi
}

show_last_cmd() {
  echo
  if [ -f "$LAST_CMD" ]; then
    cat "$LAST_CMD"
  else
    warn "暂无保存的命令。"
  fi
}

main_menu() {
  need_root

  while true; do
    show_sysinfo

    echo "1. Debian 12"
    echo "2. Debian 13"
    echo "3. Ubuntu 22.04 minimal"
    echo "4. Ubuntu 24.04 minimal"
    echo "5. Ubuntu 24.04 标准版"
    echo "6. Alpine 3.22"
    echo
    echo "7. Alpine Live 救援系统"
    echo "8. netboot.xyz 手动安装"
    echo
    echo "9. 自定义 RAW/VHD 镜像 DD"
    echo "10. Windows 自动查找 ISO"
    echo "11. Windows 自定义 ISO"
    echo
    echo "90. 查看上次生成的命令"
    echo "91. 下载/更新原版 reinstall.sh"
    echo "99. 取消误执行的重装 reset"
    echo "0. 退出"
    echo

    read -r -p "请输入选项: " num

    case "$num" in
      1) install_linux debian 12; pause ;;
      2) install_linux debian 13; pause ;;
      3) install_linux ubuntu 22.04 --minimal; pause ;;
      4) install_linux ubuntu 24.04 --minimal; pause ;;
      5) install_linux ubuntu 24.04; pause ;;
      6) install_linux alpine 3.22; pause ;;
      7) alpine_live; pause ;;
      8) netboot_menu; pause ;;
      9) dd_custom_image; pause ;;
      10) windows_auto; pause ;;
      11) windows_custom_iso; pause ;;
      90) show_last_cmd; pause ;;
      91) download_core; pause ;;
      99) reset_reinstall; pause ;;
      0) exit 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

main_menu "$@"
