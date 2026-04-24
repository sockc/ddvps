#!/usr/bin/env bash

get_os_name() {
  if [ -r /etc/os-release ]; then
    grep -E '^PRETTY_NAME=' /etc/os-release | head -n1 | cut -d= -f2- | tr -d '"' || true
  else
    echo "unknown"
  fi
}

get_virt() {
  if has_cmd systemd-detect-virt; then
    systemd-detect-virt 2>/dev/null || echo "none"
  elif [ -d /proc/vz ]; then
    echo "openvz"
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

get_default_route() {
  if has_cmd ip; then
    ip route show default 2>/dev/null | head -n1 || true
  else
    echo "unknown"
  fi
}

get_mem_total() {
  if has_cmd free; then
    free -h | awk '/Mem:/ {print $2}'
  else
    echo "unknown"
  fi
}

show_disks() {
  if has_cmd lsblk; then
    lsblk -dno NAME,SIZE,TYPE 2>/dev/null | awk '$3=="disk"{print "         /dev/"$1" "$2}' || true
  else
    echo "         unknown"
  fi
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
  echo "虚拟化 : $(get_virt)"
  echo "内存   : $(get_mem_total)"
  echo "硬盘   :"
  show_disks
  echo "公网IP : $(get_public_ip)"
  echo
}

network_check() {
  show_sysinfo
  echo -e "${BLUE}========== 网络检测 ==========${PLAIN}"
  echo "默认路由:"
  get_default_route
  echo
  echo "DNS 配置:"
  grep -E '^nameserver' /etc/resolv.conf 2>/dev/null || echo "unknown"
  echo
  echo "公网 IPv4: $(get_public_ip)"
}
