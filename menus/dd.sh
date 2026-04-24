#!/usr/bin/env bash

DD_ARGS=()

ask_dd_opts() {
  local mode="${1:-quick}"
  local img_type=""
  local cloud_data=""
  local allow_ping=""
  DD_ARGS=()

  echo
  echo "镜像类型："
  echo "1. Linux RAW/VHD"
  echo "2. Windows RAW/VHD"
  echo "3. 通用/不确定"
  read -r -p "请选择 [1-3，默认 3]: " img_type
  img_type="${img_type:-3}"

  ask_port "安装期间 SSH 观察端口" "22"
  arr_add DD_ARGS --ssh-port "$ASK_VALUE"

  if [ "$mode" = "advanced" ]; then
    append_web_port_opts DD_ARGS
  fi

  if [ "$img_type" = "1" ]; then
    read -r -p "cloud-init NoCloud 目录/URL [留空不设置]: " cloud_data
    [ -n "$cloud_data" ] && arr_add DD_ARGS --cloud-data "$cloud_data"
  fi

  if [ "$img_type" = "2" ]; then
    ask_optional_port "Windows RDP 端口，默认不修改"
    [ -n "$ASK_VALUE" ] && arr_add DD_ARGS --rdp-port "$ASK_VALUE"

    if ask_yes_no "是否允许 Windows 被 Ping？[y/N]: " "N"; then
      arr_add DD_ARGS --allow-ping
    fi

    if [ "$mode" = "advanced" ]; then
      append_frpc_opts DD_ARGS
    fi
  fi

  if [ "$mode" = "advanced" ]; then
    append_hold_opts DD_ARGS
  else
    if ask_yes_no "是否先使用 hold1 进入安装环境验证网络？[y/N]: " "N"; then
      arr_add DD_ARGS --hold 1
    fi
  fi
}

dd_image_menu() {
  local img_url=""
  check_virt_warning || return 0
  show_sysinfo
  echo -e "${BLUE}========== 自定义 RAW/VHD 镜像 DD ==========${PLAIN}"
  echo "支持 raw、固定大小 vhd，以及 .gz/.xz/.zst/.tar 等压缩包。"
  echo
  read -r -p "请输入镜像 URL: " img_url
  [ -z "$img_url" ] && { warn "镜像 URL 不能为空。"; return 0; }

  ask_install_mode
  ask_dd_opts "$PARAM_MODE"
  run_or_print dd --img "$img_url" "${DD_ARGS[@]}"
}
