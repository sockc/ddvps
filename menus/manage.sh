#!/usr/bin/env bash

show_last_cmds() {
  show_sysinfo
  echo -e "${BLUE}========== 上次生成的命令 ==========${PLAIN}"
  echo
  if [ -f "$LAST_CMD_SAFE" ]; then
    echo "脱敏命令：$LAST_CMD_SAFE"
    echo "----------------------------------------"
    cat "$LAST_CMD_SAFE"
  else
    warn "暂无脱敏命令。"
  fi
  echo
  if [ -f "$LAST_CMD_FULL" ]; then
    echo "完整命令：$LAST_CMD_FULL"
    echo "----------------------------------------"
    warn "完整命令可能包含明文密码。"
    cat "$LAST_CMD_FULL"
  else
    warn "暂无完整命令。"
  fi
}

update_ddvps_menu() {
  local installer="/tmp/ddvps-install.sh"
  info "正在下载最新 install.sh ..."
  fetch_url "https://raw.githubusercontent.com/${REPO}/${BRANCH}/install.sh" "$installer"
  chmod +x "$installer"
  REPO="$REPO" BRANCH="$BRANCH" bash "$installer"
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
  echo "Windows DD            512 MB RAM / 取决于镜像"
  echo "Windows ISO           Vista/7/8.x 512 MB；10/11/Server 2016-2025 建议 1 GB+；硬盘 25 GB+"
  echo
  warn "OpenVZ / LXC 不建议使用。"
}

manage_menu() {
  while true; do
    show_sysinfo
    echo -e "${BLUE}========== 脚本管理 ==========${PLAIN}"
    echo "1. 查看上次生成的命令"
    echo "2. 下载/更新原版 reinstall.sh"
    echo "3. 更新 DDVPS 菜单"
    echo "4. 取消误执行的重装 reset"
    echo "5. 网络检测"
    echo "6. 查看系统要求参考"
    echo "0. 返回"
    echo
    read -r -p "请输入选项: " num
    case "$num" in
      1) show_last_cmds; pause ;;
      2) download_core; pause ;;
      3) update_ddvps_menu; pause ;;
      4) reset_reinstall; pause ;;
      5) network_check; pause ;;
      6) show_requirements; pause ;;
      0) return 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}
