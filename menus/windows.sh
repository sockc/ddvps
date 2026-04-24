#!/usr/bin/env bash

WINDOWS_IMAGE_NAME=""
WINDOWS_LANG=""
WIN_ARGS=()

choose_windows_image_name() {
  local n=""
  show_sysinfo
  echo -e "${BLUE}========== Windows 映像名称 ==========${PLAIN}"
  echo "1. Windows 11 Enterprise LTSC 2024"
  echo "2. Windows 11 Pro"
  echo "3. Windows 10 Enterprise LTSC 2021"
  echo "4. Windows Server 2025 SERVERDATACENTER"
  echo "5. Windows Server 2022 SERVERDATACENTER"
  echo "6. Windows Server 2019 SERVERDATACENTER"
  echo "7. 自定义映像名称"
  echo
  read -r -p "请选择 [默认 1]: " n
  n="${n:-1}"
  case "$n" in
    1) WINDOWS_IMAGE_NAME="Windows 11 Enterprise LTSC 2024" ;;
    2) WINDOWS_IMAGE_NAME="Windows 11 Pro" ;;
    3) WINDOWS_IMAGE_NAME="Windows 10 Enterprise LTSC 2021" ;;
    4) WINDOWS_IMAGE_NAME="Windows Server 2025 SERVERDATACENTER" ;;
    5) WINDOWS_IMAGE_NAME="Windows Server 2022 SERVERDATACENTER" ;;
    6) WINDOWS_IMAGE_NAME="Windows Server 2019 SERVERDATACENTER" ;;
    7) read -r -p "请输入映像名称: " WINDOWS_IMAGE_NAME ;;
    *) WINDOWS_IMAGE_NAME="Windows 11 Enterprise LTSC 2024" ;;
  esac
}

choose_windows_lang() {
  local n=""
  echo
  echo -e "${BLUE}========== Windows 语言 ==========${PLAIN}"
  echo "1. zh-cn 简体中文"
  echo "2. zh-tw 繁体中文"
  echo "3. zh-hk 繁体中文香港"
  echo "4. en-us 英文美国"
  echo "5. en-gb 英文英国"
  echo "6. ja-jp 日文"
  echo "7. ko-kr 韩文"
  echo "8. 自定义语言代码"
  echo
  read -r -p "请选择 [默认 1]: " n
  n="${n:-1}"
  case "$n" in
    1) WINDOWS_LANG="zh-cn" ;;
    2) WINDOWS_LANG="zh-tw" ;;
    3) WINDOWS_LANG="zh-hk" ;;
    4) WINDOWS_LANG="en-us" ;;
    5) WINDOWS_LANG="en-gb" ;;
    6) WINDOWS_LANG="ja-jp" ;;
    7) WINDOWS_LANG="ko-kr" ;;
    8) read -r -p "请输入语言代码，例如 de-de/fr-fr/pt-br: " WINDOWS_LANG ;;
    *) WINDOWS_LANG="zh-cn" ;;
  esac
}

ask_windows_opts() {
  local mode="${1:-quick}"
  local pass=""
  local allow_ping=""
  local driver=""
  local boot_mode=""
  WIN_ARGS=()

  read -r -s -p "Administrator 密码 [留空随机]: " pass
  echo
  [ -n "$pass" ] && arr_add WIN_ARGS --password "$pass"

  ask_optional_port "RDP 端口，默认 3389，不改则留空"
  [ -n "$ASK_VALUE" ] && arr_add WIN_ARGS --rdp-port "$ASK_VALUE"

  ask_port "安装期间 SSH 观察端口" "22"
  arr_add WIN_ARGS --ssh-port "$ASK_VALUE"

  if [ "$mode" = "advanced" ]; then
    append_web_port_opts WIN_ARGS

    if ask_yes_no "是否允许 Windows 被 Ping？[y/N]: " "N"; then
      arr_add WIN_ARGS --allow-ping
    fi

    append_frpc_opts WIN_ARGS

    while true; do
      read -r -p "额外驱动 .inf 或目录 [留空结束]: " driver
      [ -z "$driver" ] && break
      arr_add WIN_ARGS --add-driver "$driver"
    done

    echo
    echo "强制引导模式："
    echo "0. 不设置"
    echo "1. BIOS"
    echo "2. EFI"
    read -r -p "请选择 [0-2，默认 0]: " boot_mode
    boot_mode="${boot_mode:-0}"
    case "$boot_mode" in
      1) arr_add WIN_ARGS --force-boot-mode bios ;;
      2) arr_add WIN_ARGS --force-boot-mode efi ;;
    esac

    append_hold_opts WIN_ARGS
  else
    if ask_yes_no "是否先使用 hold1 进入安装环境验证网络？[y/N]: " "N"; then
      arr_add WIN_ARGS --hold 1
    fi
  fi
}

windows_auto_iso() {
  check_virt_warning || return 0
  choose_windows_image_name
  [ -z "$WINDOWS_IMAGE_NAME" ] && { warn "映像名称不能为空。"; return 0; }
  choose_windows_lang
  [ -z "$WINDOWS_LANG" ] && WINDOWS_LANG="zh-cn"
  ask_install_mode
  ask_windows_opts "$PARAM_MODE"
  run_or_print windows --image-name "$WINDOWS_IMAGE_NAME" --lang "$WINDOWS_LANG" "${WIN_ARGS[@]}"
}

windows_custom_iso() {
  local iso_url=""
  check_virt_warning || return 0
  choose_windows_image_name
  [ -z "$WINDOWS_IMAGE_NAME" ] && { warn "映像名称不能为空。"; return 0; }
  echo
  read -r -p "请输入 ISO URL 或磁力链接: " iso_url
  [ -z "$iso_url" ] && { warn "ISO URL 不能为空。"; return 0; }
  ask_install_mode
  ask_windows_opts "$PARAM_MODE"
  run_or_print windows --image-name "$WINDOWS_IMAGE_NAME" --iso "$iso_url" "${WIN_ARGS[@]}"
}

windows_menu() {
  while true; do
    show_sysinfo
    echo -e "${BLUE}========== Windows 重装 ==========${PLAIN}"
    echo "1. 自动查找官方 ISO"
    echo "2. 自定义 ISO URL / 磁力链接"
    echo "0. 返回"
    echo
    read -r -p "请输入选项: " num
    case "$num" in
      1) windows_auto_iso; pause ;;
      2) windows_custom_iso; pause ;;
      0) return 0 ;;
      *) warn "无效选项"; pause ;;
    esac
  done
}
