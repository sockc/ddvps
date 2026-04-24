#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-sockc/ddvps}"
BRANCH="${BRANCH:-main}"
UPSTREAM_REINSTALL_URL="${UPSTREAM_REINSTALL_URL:-https://raw.githubusercontent.com/bin456789/reinstall/main/reinstall.sh}"
CORE="${CORE:-/root/reinstall.sh}"
LAST_CMD="${LAST_CMD:-/root/ddvps-last-command.txt}"

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
  read -r -p "按回车返回菜单..." _ || true
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

need_root() {
  if [ "$(id -u)" != "0" ]; then
    err "请使用 root 用户运行。"
    exit 1
  fi
}

get_os_name() {
  if [ -r /etc/os-release ]; then
    grep -E '^PRETTY_NAME=' /etc/os-release | head -n1 | cut -d= -f2- | tr -d '"' || true
  else
    echo "unknown"
  fi
}

get_public_ip() {
  if has_cmd curl; then
    curl -4 -s --connect-timeout 3 https://api.ipify.org 2>/dev/null || echo "unknown"
  elif has_cmd wget; then
    wget -qO- --timeout=3 https://api.ipify.org 2>/dev/null || echo "unknown"
  else
    echo "unknown"
  fi
}

download_core() {
  info "正在下载原版 reinstall.sh ..."
  rm -f "$CORE"

  if has_cmd curl; then
    curl -L --connect-timeout 10 --retry 2 -o "$CORE" "$UPSTREAM_REINSTALL_URL"
  elif has_cmd wget; then
    wget -O "$CORE" "$UPSTREAM_REINSTALL_URL"
  else
    err "未找到 curl 或 wget，无法下载 reinstall.sh。"
    exit 1
  fi

  if [ ! -s "$CORE" ]; then
    err "reinstall.sh 下载失败或文件为空。"
    exit 1
  fi

  chmod +x "$CORE"
  info "原版 reinstall.sh 已下载到：$CORE"
}

show_sysinfo() {
  clear || true
  echo -e "${BLUE}========== DDVPS 重装增强菜单 ==========${PLAIN}"
  echo "仓库   : $REPO"
  echo "分支   : $BRANCH"
  echo "核心   : bin456789/reinstall"
  echo
  echo -e "${BLUE}========== 当前机器信息 ==========${PLAIN}"
  echo "主机名 : $(hostname 2>/dev/null || echo unknown)"
  echo "系统   : $(get_os_name)"
  echo "架构   : $(uname -m 2>/dev/null || echo unknown)"
  echo "内核   : $(uname -r 2>/dev/null || echo unknown)"

  if has_cmd systemd-detect-virt; then
    echo "虚拟化 : $(systemd-detect-virt 2>/dev/null || echo none)"
  else
    echo "虚拟化 : unknown"
  fi

  if has_cmd free; then
    echo "内存   : $(free -h | awk '/Mem:/ {print $2}')"
  else
    echo "内存   : unknown"
  fi

  echo "硬盘   :"
  if has_cmd lsblk; then
    lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print "         /dev/"$1" "$2}' || true
  else
    echo "         unknown"
  fi

  echo "公网IP : $(get_public_ip)"
  echo
}

check_virt_warning() {
  local virt=""
  if has_cmd systemd-detect-virt; then
    virt="$(systemd-detect-virt 2>/dev/null || true)"
  fi

  if [ "$virt" = "openvz" ] || [ "$virt" = "lxc" ] || [ -d /proc/vz ]; then
    warn "检测到 OpenVZ/LXC/容器环境。原版 reinstall 明确不支持这类虚拟化。"
    warn "继续可能导致失联或无法启动。"
    echo
    read -r -p "仍要强制继续？输入 YES 继续，其它返回: " x
    [ "$x" = "YES" ] || return 1
  fi

  return 0
}

confirm_danger() {
  echo
  err "危险操作：该操作可能清空当前 VPS 整个硬盘。"
  err "请确保已经备份数据，并且有商家控制台/VNC/救援模式。"
  warn "误执行后，重启前可尝试执行：bash $CORE reset"
  echo
  read -r -p "请输入 YES 确认继续: " yes
  [ "$yes" = "YES" ] || {
    warn "已取消。"
    return 1
  }
  return 0
}

append_hold_opts() {
  local target_array_name="$1"
  local hold_mode=""

  echo
  echo "hold 模式："
  echo "0. 不使用"
  echo "1. 只进入安装环境，先验证 SSH/网络，不执行安装"
  echo "2. 安装结束后不自动重启，方便 SSH 检查"
  read -r -p "请选择 [0-2，默认 0]: " hold_mode
  hold_mode="${hold_mode:-0}"

  case "$hold_mode" in
    1) eval "$target_array_name+=(--hold 1)" ;;
    2) eval "$target_array_name+=(--hold 2)" ;;
  esac
}

ask_login_opts() {
  local target_array_name="$1"
  local login_mode=""

  echo
  echo "登录方式："
  echo "1. 设置 root/administrator 密码"
  echo "2. 使用 SSH 公钥"
  echo "3. 不设置，让原脚本提示或随机生成"
  read -r -p "请选择 [1-3，默认 1]: " login_mode
  login_mode="${login_mode:-1}"

  case "$login_mode" in
    1)
      local pass=""
      read -r -s -p "请输入密码: " pass
      echo
      if [ -n "$pass" ]; then
        eval "$target_array_name+=(--password \"\$pass\")"
      else
        warn "密码为空，将交给原脚本处理。"
      fi
      ;;
    2)
      local key=""
      read -r -p "粘贴 SSH 公钥: " key
      if [ -n "$key" ]; then
        eval "$target_array_name+=(--ssh-key \"\$key\")"
      else
        warn "公钥为空，已跳过。"
      fi
      ;;
    *) ;;
  esac
}

ask_common_linux_opts() {
  COMMON_ARGS=()

  local ssh_port=""
  read -r -p "SSH 端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  COMMON_ARGS+=(--ssh-port "$ssh_port")

  local web_port=""
  read -r -p "Web 观察端口 [默认不设置]: " web_port
  [ -n "$web_port" ] && COMMON_ARGS+=(--web-port "$web_port")

  ask_login_opts COMMON_ARGS

  local frpc_config=""
  read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
  [ -n "$frpc_config" ] && COMMON_ARGS+=(--frpc-config "$frpc_config")

  append_hold_opts COMMON_ARGS
}

save_cmd() {
  {
    echo "# 生成时间: $(date '+%F %T')"
    if has_cmd curl; then
      printf 'curl -L -o %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
    else
      printf 'wget -O %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
    fi
    printf 'chmod +x %q\n' "$CORE"
    printf 'bash %q' "$CORE"
    local arg
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    echo
  } > "$LAST_CMD"
  chmod 600 "$LAST_CMD" 2>/dev/null || true
}

show_exec_cmd() {
  echo -e "${BLUE}即将生成/执行的命令：${PLAIN}"
  if has_cmd curl; then
    printf 'curl -L -o %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
  else
    printf 'wget -O %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
  fi
  printf 'chmod +x %q\n' "$CORE"
  printf 'bash %q' "$CORE"
  local arg
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  echo
}

run_or_print() {
  local args=("$@")

  echo
  show_exec_cmd "${args[@]}"
  echo
  save_cmd "${args[@]}"
  info "命令已保存到：$LAST_CMD"
  warn "注意：如果命令里包含密码，$LAST_CMD 也会保存密码。"
  echo
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
  local version="$2"
  shift 2 || true

  check_virt_warning || return 0
  ask_common_linux_opts

  local args=("$distro")
  [ -n "$version" ] && args+=("$version")
  args+=("$@")
  args+=("${COMMON_ARGS[@]}")

  run_or_print "${args[@]}"
}

choose_version_install() {
  local title="$1"
  local distro="$2"
  local versions="$3"
  shift 3 || true
  local extra=("$@")
  local arr=()
  local v=""
  local i=2
  local choice=""

  show_sysinfo
  echo -e "${BLUE}========== $title 版本选择 ==========${PLAIN}"
  echo "1. 最新版/默认版本（不指定版本号）"
  for v in $versions; do
    echo "$i. $v"
    arr+=("$v")
    i=$((i + 1))
  done
  echo "0. 返回"
  echo
  read -r -p "请选择版本: " choice

  if [ "$choice" = "0" ]; then
    return 0
  fi

  if [ "$choice" = "1" ]; then
    install_linux "$distro" "" "${extra[@]}"
    return 0
  fi

  if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
    warn "无效选项。"
    return 0
  fi

  local idx=$((choice - 2))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#arr[@]}" ]; then
    warn "无效选项。"
    return 0
  fi

  install_linux "$distro" "${arr[$idx]}" "${extra[@]}"
}

debian_menu() {
  show_sysinfo
  echo -e "${BLUE}========== Debian ==========${PLAIN}"
  echo "1. 最新版/默认版本"
  echo "2. Debian 9"
  echo "3. Debian 10"
  echo "4. Debian 11"
  echo "5. Debian 12"
  echo "6. Debian 13"
  echo "7. Debian 云镜像安装 --ci（适合 CPU 较慢机器）"
  echo "0. 返回"
  echo
  read -r -p "请选择: " n
  case "$n" in
    1) install_linux debian "" ;;
    2) install_linux debian 9 ;;
    3) install_linux debian 10 ;;
    4) install_linux debian 11 ;;
    5) install_linux debian 12 ;;
    6) install_linux debian 13 ;;
    7) install_linux debian "" --ci ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

ubuntu_menu() {
  local versions="18.04 20.04 22.04 24.04 26.04"
  local arr=()
  local v=""
  local i=2
  local choice=""
  local version=""
  local minimal=""
  local extra=()

  show_sysinfo
  echo -e "${BLUE}========== Ubuntu 版本选择 ==========${PLAIN}"
  echo "1. 最新版/默认版本"
  for v in $versions; do
    echo "$i. Ubuntu $v"
    arr+=("$v")
    i=$((i + 1))
  done
  echo "9. Ubuntu ISO 安装器 --installer（实验功能）"
  echo "0. 返回"
  echo
  read -r -p "请选择版本: " choice

  case "$choice" in
    0) return 0 ;;
    1) version="" ;;
    9) install_linux ubuntu "" --installer; return 0 ;;
    *)
      if ! [[ "$choice" =~ ^[0-9]+$ ]]; then warn "无效选项"; return 0; fi
      local idx=$((choice - 2))
      if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#arr[@]}" ]; then warn "无效选项"; return 0; fi
      version="${arr[$idx]}"
      ;;
  esac

  read -r -p "是否使用 --minimal 轻量安装？[Y/n]: " minimal
  minimal="${minimal:-Y}"
  [[ "$minimal" =~ ^[Yy]$ ]] && extra+=(--minimal)
  install_linux ubuntu "$version" "${extra[@]}"
}

redhat_menu() {
  show_sysinfo
  echo -e "${BLUE}========== Red Hat / 自定义 qcow2 ==========${PLAIN}"
  echo "需要填写 RHEL 官方 qcow2 链接，也可填其它类 RHEL 系统 qcow2。"
  echo
  local img=""
  read -r -p "请输入 qcow2 镜像 URL: " img
  if [ -z "$img" ]; then
    warn "镜像 URL 不能为空。"
    return 0
  fi
  install_linux redhat "" "--img=$img"
}

installer_menu() {
  show_sysinfo
  echo -e "${BLUE}========== 高级/实验安装器 ==========${PLAIN}"
  warn "这些是上游实验功能，通常要求动态 IP 和更高内存；不支持通过参数修改密码/SSH 端口。"
  echo
  echo "1. CentOS Stream --installer"
  echo "2. AlmaLinux --installer"
  echo "3. Rocky Linux --installer"
  echo "4. Fedora --installer"
  echo "5. Ubuntu --installer"
  echo "0. 返回"
  echo
  read -r -p "请选择: " n
  case "$n" in
    1) install_linux centos "" --installer ;;
    2) install_linux almalinux "" --installer ;;
    3) install_linux rocky "" --installer ;;
    4) install_linux fedora "" --installer ;;
    5) install_linux ubuntu "" --installer ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

ask_dd_opts() {
  DD_ARGS=()

  local img_type=""
  echo
  echo "镜像类型："
  echo "1. Linux RAW/VHD"
  echo "2. Windows RAW/VHD"
  echo "3. 不确定/通用"
  read -r -p "请选择 [1-3，默认 3]: " img_type
  img_type="${img_type:-3}"

  local ssh_port=""
  read -r -p "SSH 观察端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  DD_ARGS+=(--ssh-port "$ssh_port")

  local web_port=""
  read -r -p "Web 观察端口 [默认不设置]: " web_port
  [ -n "$web_port" ] && DD_ARGS+=(--web-port "$web_port")

  if [ "$img_type" = "1" ]; then
    local cloud_data=""
    read -r -p "cloud-init NoCloud 目录/URL [默认不设置]: " cloud_data
    [ -n "$cloud_data" ] && DD_ARGS+=(--cloud-data "$cloud_data")
  fi

  if [ "$img_type" = "2" ]; then
    local rdp_port=""
    read -r -p "RDP 端口 [默认不修改]: " rdp_port
    [ -n "$rdp_port" ] && DD_ARGS+=(--rdp-port "$rdp_port")

    local allow_ping=""
    read -r -p "是否允许 Windows 被 Ping？[y/N]: " allow_ping
    [[ "$allow_ping" =~ ^[Yy]$ ]] && DD_ARGS+=(--allow-ping)

    local frpc_config=""
    read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
    [ -n "$frpc_config" ] && DD_ARGS+=(--frpc-config "$frpc_config")
  fi

  append_hold_opts DD_ARGS
}

dd_custom_image() {
  check_virt_warning || return 0

  show_sysinfo
  echo -e "${BLUE}========== 自定义 RAW/VHD 镜像 DD ==========${PLAIN}"
  echo "支持 raw、固定大小 vhd，以及 .gz/.xz/.zst/.tar 等压缩包。"
  echo
  local img_url=""
  read -r -p "请输入镜像 URL: " img_url
  if [ -z "$img_url" ]; then
    warn "镜像 URL 不能为空。"
    return 0
  fi

  ask_dd_opts
  run_or_print dd --img "$img_url" "${DD_ARGS[@]}"
}

ask_windows_opts() {
  WIN_ARGS=()

  ask_login_opts WIN_ARGS

  local rdp_port=""
  read -r -p "RDP 端口 [默认 3389，不修改则留空]: " rdp_port
  [ -n "$rdp_port" ] && WIN_ARGS+=(--rdp-port "$rdp_port")

  local ssh_port=""
  read -r -p "安装期间 SSH 观察端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  WIN_ARGS+=(--ssh-port "$ssh_port")

  local web_port=""
  read -r -p "安装期间 Web 观察端口 [默认不设置]: " web_port
  [ -n "$web_port" ] && WIN_ARGS+=(--web-port "$web_port")

  local allow_ping=""
  read -r -p "是否允许 Windows 被 Ping？[y/N]: " allow_ping
  [[ "$allow_ping" =~ ^[Yy]$ ]] && WIN_ARGS+=(--allow-ping)

  local frpc_config=""
  read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
  [ -n "$frpc_config" ] && WIN_ARGS+=(--frpc-config "$frpc_config")

  while true; do
    local driver=""
    read -r -p "额外驱动 .inf 或目录 [留空结束]: " driver
    [ -z "$driver" ] && break
    WIN_ARGS+=(--add-driver "$driver")
  done

  local boot_mode=""
  echo
  echo "强制引导模式："
  echo "0. 不设置"
  echo "1. BIOS"
  echo "2. EFI"
  read -r -p "请选择 [0-2，默认 0]: " boot_mode
  boot_mode="${boot_mode:-0}"
  case "$boot_mode" in
    1) WIN_ARGS+=(--force-boot-mode bios) ;;
    2) WIN_ARGS+=(--force-boot-mode efi) ;;
  esac

  append_hold_opts WIN_ARGS
}

choose_windows_image_name() {
  local image_name=""
  echo "1. Windows 11 Enterprise LTSC 2024"
  echo "2. Windows 11 Pro"
  echo "3. Windows 10 Enterprise LTSC 2021"
  echo "4. Windows Server 2025 SERVERDATACENTER"
  echo "5. Windows Server 2022 SERVERDATACENTER"
  echo "6. 自定义映像名称"
  echo
  read -r -p "请选择映像名称 [默认 1]: " n
  n="${n:-1}"
  case "$n" in
    1) image_name="Windows 11 Enterprise LTSC 2024" ;;
    2) image_name="Windows 11 Pro" ;;
    3) image_name="Windows 10 Enterprise LTSC 2021" ;;
    4) image_name="Windows Server 2025 SERVERDATACENTER" ;;
    5) image_name="Windows Server 2022 SERVERDATACENTER" ;;
    6) read -r -p "请输入映像名称: " image_name ;;
    *) image_name="Windows 11 Enterprise LTSC 2024" ;;
  esac
  echo "$image_name"
}

choose_windows_lang() {
  local lang=""
  echo "1. zh-cn 简体中文"
  echo "2. zh-tw 繁体中文"
  echo "3. en-us 英文美国"
  echo "4. en-gb 英文英国"
  echo "5. ja-jp 日文"
  echo "6. ko-kr 韩文"
  echo "7. 自定义语言代码"
  echo
  read -r -p "请选择语言 [默认 1]: " n
  n="${n:-1}"
  case "$n" in
    1) lang="zh-cn" ;;
    2) lang="zh-tw" ;;
    3) lang="en-us" ;;
    4) lang="en-gb" ;;
    5) lang="ja-jp" ;;
    6) lang="ko-kr" ;;
    7) read -r -p "请输入语言代码，例如 zh-hk/de-de/fr-fr: " lang ;;
    *) lang="zh-cn" ;;
  esac
  echo "$lang"
}

windows_auto() {
  check_virt_warning || return 0
  show_sysinfo
  echo -e "${BLUE}========== Windows 自动查找 ISO ==========${PLAIN}"
  echo "上游自动查找通常适用于 Windows 10/11、Server 2019/2022/2025。"
  echo
  local image_name
  image_name="$(choose_windows_image_name)"
  echo
  local lang
  lang="$(choose_windows_lang)"
  ask_windows_opts
  run_or_print windows --image-name "$image_name" --lang "$lang" "${WIN_ARGS[@]}"
}

windows_custom_iso() {
  check_virt_warning || return 0
  show_sysinfo
  echo -e "${BLUE}========== Windows 自定义 ISO ==========${PLAIN}"
  echo
  local image_name=""
  local iso_url=""
  read -r -p "Windows 映像名称: " image_name
  read -r -p "ISO URL/磁力链接: " iso_url

  if [ -z "$image_name" ] || [ -z "$iso_url" ]; then
    warn "映像名称和 ISO 链接不能为空。"
    return 0
  fi

  ask_windows_opts
  run_or_print windows --image-name "$image_name" --iso "$iso_url" "${WIN_ARGS[@]}"
}

windows_menu() {
  show_sysinfo
  echo -e "${BLUE}========== Windows ==========${PLAIN}"
  echo "1. 自动查找官方 ISO"
  echo "2. 自定义 ISO URL/磁力链接"
  echo "0. 返回"
  echo
  read -r -p "请选择: " n
  case "$n" in
    1) windows_auto ;;
    2) windows_custom_iso ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

rescue_alpine_live() {
  check_virt_warning || return 0
  RESCUE_ARGS=()

  local ssh_port=""
  read -r -p "SSH 端口 [默认 22]: " ssh_port
  ssh_port="${ssh_port:-22}"
  RESCUE_ARGS+=(--ssh-port "$ssh_port")

  ask_login_opts RESCUE_ARGS

  local frpc_config=""
  read -r -p "frpc 配置文件路径/URL [默认不设置]: " frpc_config
  [ -n "$frpc_config" ] && RESCUE_ARGS+=(--frpc-config "$frpc_config")

  run_or_print alpine --hold 1 "${RESCUE_ARGS[@]}"
}

rescue_menu() {
  show_sysinfo
  echo -e "${BLUE}========== 救援/手动引导 ==========${PLAIN}"
  echo "1. Alpine Live OS 内存救援系统"
  echo "2. netboot.xyz 手动安装"
  echo "0. 返回"
  echo
  read -r -p "请选择: " n
  case "$n" in
    1) rescue_alpine_live ;;
    2) check_virt_warning && run_or_print netboot.xyz ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

show_last_cmd() {
  echo
  if [ -f "$LAST_CMD" ]; then
    cat "$LAST_CMD"
  else
    warn "暂无保存的命令。"
  fi
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

show_requirements() {
  show_sysinfo
  echo -e "${BLUE}========== 常见目标系统最低要求参考 ==========${PLAIN}"
  echo "Alpine                256 MB RAM / 1 GB 硬盘"
  echo "Debian / Kali         256 MB RAM / 1~1.5 GB 硬盘"
  echo "Ubuntu                512 MB RAM / 2 GB 硬盘"
  echo "RHEL 系 / Fedora 等   512 MB RAM / 5 GB 硬盘"
  echo "NixOS/Arch/Gentoo     512 MB RAM / 5 GB 硬盘"
  echo "fnOS                  512 MB RAM / 8 GB 硬盘"
  echo "Windows ISO           Vista/7/8.x 512 MB；10/11/Server 2016-2025 建议 1 GB+；硬盘 25 GB+"
  echo
  warn "OpenVZ / LXC 不支持。"
}

main_menu() {
  need_root

  while true; do
    show_sysinfo
    echo "1. Debian"
    echo "2. Ubuntu"
    echo "3. Alpine"
    echo "4. Kali"
    echo "5. AlmaLinux"
    echo "6. Rocky Linux"
    echo "7. Oracle Linux"
    echo "8. CentOS Stream"
    echo "9. Fedora"
    echo "10. openSUSE"
    echo "11. openEuler"
    echo "12. OpenCloudOS"
    echo "13. Anolis OS"
    echo "14. NixOS"
    echo "15. Arch Linux"
    echo "16. Gentoo"
    echo "17. AOSC OS / 安同 OS"
    echo "18. fnOS / 飞牛 OS"
    echo "19. Red Hat / 自定义 qcow2"
    echo
    echo "20. Windows"
    echo "21. 自定义 RAW/VHD 镜像 DD"
    echo "22. Alpine Live / netboot.xyz 救援引导"
    echo "23. 高级/实验安装器"
    echo
    echo "80. 查看系统要求参考"
    echo "90. 查看上次生成的命令"
    echo "91. 下载/更新原版 reinstall.sh"
    echo "99. 取消误执行的重装 reset"
    echo "0. 退出"
    echo
    read -r -p "请输入选项: " num

    case "$num" in
      1) debian_menu; pause ;;
      2) ubuntu_menu; pause ;;
      3) choose_version_install "Alpine" alpine "3.20 3.21 3.22 3.23"; pause ;;
      4) install_linux kali ""; pause ;;
      5) choose_version_install "AlmaLinux" almalinux "8 9 10"; pause ;;
      6) choose_version_install "Rocky Linux" rocky "8 9 10"; pause ;;
      7) choose_version_install "Oracle Linux" oracle "8 9 10"; pause ;;
      8) choose_version_install "CentOS Stream" centos "9 10"; pause ;;
      9) choose_version_install "Fedora" fedora "42 43"; pause ;;
      10) choose_version_install "openSUSE" opensuse "15.6 16.0 tumbleweed"; pause ;;
      11) choose_version_install "openEuler" openeuler "20.03 22.03 24.03 25.09"; pause ;;
      12) choose_version_install "OpenCloudOS" opencloudos "8 9 23"; pause ;;
      13) choose_version_install "Anolis OS" anolis "7 8 23"; pause ;;
      14) choose_version_install "NixOS" nixos "25.11"; pause ;;
      15) install_linux arch ""; pause ;;
      16) install_linux gentoo ""; pause ;;
      17) install_linux aosc ""; pause ;;
      18) choose_version_install "fnOS / 飞牛 OS" fnos "1"; pause ;;
      19) redhat_menu; pause ;;
      20) windows_menu; pause ;;
      21) dd_custom_image; pause ;;
      22) rescue_menu; pause ;;
      23) installer_menu; pause ;;
      80) show_requirements; pause ;;
      90) show_last_cmd; pause ;;
      91) download_core; pause ;;
      99) reset_reinstall; pause ;;
      0) exit 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}

main_menu "$@"
