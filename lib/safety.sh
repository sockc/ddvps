#!/usr/bin/env bash

check_virt_warning() {
  local virt="$(get_virt)"
  if [ "$virt" = "openvz" ] || [ "$virt" = "lxc" ] || [ -d /proc/vz ]; then
    warn "检测到 OpenVZ/LXC/容器环境。原版 reinstall 不适合这类虚拟化。"
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
  err "请确认已经备份数据，并且有商家控制台/VNC/救援模式。"
  warn "误执行后，在重启前可尝试执行：bash $CORE reset"
  echo
  read -r -p "请输入 YES 确认继续: " yes
  [ "$yes" = "YES" ] || {
    warn "已取消。"
    return 1
  }
  return 0
}

confirm_non_destructive_rescue() {
  echo
  warn "Alpine Live / netboot.xyz 本身不会自动清盘，但你进入后手动操作仍可能破坏数据。"
  read -r -p "输入 YES 继续: " yes
  [ "$yes" = "YES" ] || return 1
}
