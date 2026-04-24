#!/usr/bin/env bash

RESCUE_ARGS=()

rescue_alpine_live() {
  check_virt_warning || return 0
  confirm_non_destructive_rescue || return 0
  RESCUE_ARGS=()

  ask_port "SSH 端口" "22"
  arr_add RESCUE_ARGS --ssh-port "$ASK_VALUE"
  ask_login_opts RESCUE_ARGS "root"
  append_frpc_opts RESCUE_ARGS

  run_or_print alpine --hold 1 "${RESCUE_ARGS[@]}"
}

rescue_netboot() {
  check_virt_warning || return 0
  confirm_non_destructive_rescue || return 0
  run_or_print netboot.xyz
}

rescue_menu() {
  while true; do
    show_sysinfo
    echo -e "${BLUE}========== 救援/手动引导 ==========${PLAIN}"
    echo "1. Alpine Live OS 内存救援系统"
    echo "2. netboot.xyz 手动安装"
    echo "0. 返回"
    echo
    read -r -p "请输入选项: " num
    case "$num" in
      1) rescue_alpine_live; pause ;;
      2) rescue_netboot; pause ;;
      0) return 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}
