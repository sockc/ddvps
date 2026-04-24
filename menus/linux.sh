#!/usr/bin/env bash

install_linux() {
  local distro="$1"
  local version="${2:-}"
  shift 2 || true
  local extra=("$@")
  local args=()

  check_virt_warning || return 0
  ask_install_mode
  ask_common_linux_opts "$PARAM_MODE"

  args+=("$distro")
  [ -n "$version" ] && args+=("$version")
  args+=("${extra[@]}")
  args+=("${COMMON_ARGS[@]}")

  run_or_print "${args[@]}"
}

generic_version_menu() {
  local title="$1"
  local distro="$2"
  local versions="$3"
  shift 3 || true
  local extra=("$@")
  local list=()
  local v choice idx

  show_sysinfo
  echo -e "${BLUE}========== $title 版本选择 ==========${PLAIN}"
  echo "1. 最新版/默认版本（不指定版本号）"
  local i=2
  for v in $versions; do
    echo "$i. $title $v"
    list+=("$v")
    i=$((i + 1))
  done
  echo "0. 返回"
  echo
  read -r -p "请选择版本: " choice

  case "$choice" in
    0) return 0 ;;
    1) install_linux "$distro" "" "${extra[@]}"; return 0 ;;
  esac

  if ! is_uint "$choice"; then
    warn "无效选项。"
    return 0
  fi

  idx=$((choice - 2))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#list[@]}" ]; then
    warn "无效选项。"
    return 0
  fi

  install_linux "$distro" "${list[$idx]}" "${extra[@]}"
}

debian_menu() {
  local choice=""
  show_sysinfo
  echo -e "${BLUE}========== Debian ==========${PLAIN}"
  echo "1. 最新版/默认版本"
  echo "2. 选择 Debian 版本"
  echo "3. Debian 云镜像安装 --ci（适合 CPU 较慢机器）"
  echo "0. 返回"
  echo
  read -r -p "请选择: " choice
  case "$choice" in
    1) install_linux debian "" ;;
    2) generic_version_menu "Debian" debian "$DISTRO_DEBIAN_VERSIONS" ;;
    3) generic_version_menu "Debian --ci" debian "$DISTRO_DEBIAN_VERSIONS" --ci ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

ubuntu_menu() {
  local versions="$DISTRO_UBUNTU_VERSIONS"
  local list=()
  local v choice idx version minimal

  show_sysinfo
  echo -e "${BLUE}========== Ubuntu 版本选择 ==========${PLAIN}"
  echo "1. 最新版/默认版本"
  local i=2
  for v in $versions; do
    echo "$i. Ubuntu $v"
    list+=("$v")
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
      if ! is_uint "$choice"; then warn "无效选项"; return 0; fi
      idx=$((choice - 2))
      if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#list[@]}" ]; then warn "无效选项"; return 0; fi
      version="${list[$idx]}"
      ;;
  esac

  read -r -p "是否使用 --minimal 轻量安装？[Y/n]: " minimal
  minimal="${minimal:-Y}"
  if [[ "$minimal" =~ ^[Yy]$ ]]; then
    install_linux ubuntu "$version" --minimal
  else
    install_linux ubuntu "$version"
  fi
}

rhel_family_menu() {
  local choice=""
  show_sysinfo
  echo -e "${BLUE}========== RHEL 系 ==========${PLAIN}"
  echo "1. AlmaLinux"
  echo "2. Rocky Linux"
  echo "3. Oracle Linux"
  echo "4. CentOS Stream"
  echo "5. Fedora"
  echo "6. Red Hat / 自定义 qcow2"
  echo "0. 返回"
  echo
  read -r -p "请选择: " choice
  case "$choice" in
    1) generic_version_menu "AlmaLinux" almalinux "$DISTRO_ALMALINUX_VERSIONS" ;;
    2) generic_version_menu "Rocky Linux" rocky "$DISTRO_ROCKY_VERSIONS" ;;
    3) generic_version_menu "Oracle Linux" oracle "$DISTRO_ORACLE_VERSIONS" ;;
    4) generic_version_menu "CentOS Stream" centos "$DISTRO_CENTOS_VERSIONS" ;;
    5) generic_version_menu "Fedora" fedora "$DISTRO_FEDORA_VERSIONS" ;;
    6) redhat_custom_qcow2 ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

redhat_custom_qcow2() {
  local img=""
  show_sysinfo
  echo -e "${BLUE}========== Red Hat / 自定义 qcow2 ==========${PLAIN}"
  echo "这里需要填写 RHEL 官方 qcow2 链接，也可填其它类 RHEL 系统 qcow2。"
  echo
  read -r -p "请输入 qcow2 镜像 URL: " img
  if [ -z "$img" ]; then
    warn "镜像 URL 不能为空。"
    return 0
  fi
  install_linux redhat "" "--img=$img"
}

other_linux_menu() {
  local choice=""
  show_sysinfo
  echo -e "${BLUE}========== 其它 Linux ==========${PLAIN}"
  echo "1. Kali"
  echo "2. openSUSE"
  echo "3. openEuler"
  echo "4. OpenCloudOS"
  echo "5. Anolis OS"
  echo "6. NixOS"
  echo "7. Arch Linux"
  echo "8. Gentoo"
  echo "9. AOSC OS / 安同 OS"
  echo "10. fnOS / 飞牛 OS"
  echo "0. 返回"
  echo
  read -r -p "请选择: " choice
  case "$choice" in
    1) install_linux kali "" ;;
    2) generic_version_menu "openSUSE" opensuse "$DISTRO_OPENSUSE_VERSIONS" ;;
    3) generic_version_menu "openEuler" openeuler "$DISTRO_OPENEULER_VERSIONS" ;;
    4) generic_version_menu "OpenCloudOS" opencloudos "$DISTRO_OPENCLOUDOS_VERSIONS" ;;
    5) generic_version_menu "Anolis OS" anolis "$DISTRO_ANOLIS_VERSIONS" ;;
    6) generic_version_menu "NixOS" nixos "$DISTRO_NIXOS_VERSIONS" ;;
    7) install_linux arch "" ;;
    8) install_linux gentoo "" ;;
    9) install_linux aosc "" ;;
    10) generic_version_menu "fnOS / 飞牛 OS" fnos "$DISTRO_FNOS_VERSIONS" ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

installer_menu() {
  local choice=""
  show_sysinfo
  echo -e "${BLUE}========== 高级/实验安装器 ==========${PLAIN}"
  warn "这些是上游实验功能，通常要求动态 IP 和更高内存；部分参数可能无法作用于最终系统。"
  echo
  echo "1. CentOS Stream --installer"
  echo "2. AlmaLinux --installer"
  echo "3. Rocky Linux --installer"
  echo "4. Fedora --installer"
  echo "5. Ubuntu --installer"
  echo "0. 返回"
  echo
  read -r -p "请选择: " choice
  case "$choice" in
    1) install_linux centos "" --installer ;;
    2) install_linux almalinux "" --installer ;;
    3) install_linux rocky "" --installer ;;
    4) install_linux fedora "" --installer ;;
    5) install_linux ubuntu "" --installer ;;
    0) return 0 ;;
    *) warn "无效选项" ;;
  esac
}

linux_menu() {
  while true; do
    show_sysinfo
    echo "1. Debian"
    echo "2. Ubuntu"
    echo "3. Alpine"
    echo "4. RHEL 系：Alma/Rocky/Oracle/CentOS/Fedora"
    echo "5. 其它 Linux：Kali/openSUSE/NixOS/Arch/Gentoo/fnOS 等"
    echo "6. 高级/实验安装器"
    echo "0. 返回"
    echo
    read -r -p "请输入选项: " num
    case "$num" in
      1) debian_menu; pause ;;
      2) ubuntu_menu; pause ;;
      3) generic_version_menu "Alpine" alpine "$DISTRO_ALPINE_VERSIONS"; pause ;;
      4) rhel_family_menu; pause ;;
      5) other_linux_menu; pause ;;
      6) installer_menu; pause ;;
      0) return 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}
