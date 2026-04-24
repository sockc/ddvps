#!/usr/bin/env bash

ASK_VALUE=""
PARAM_MODE="quick"
COMMON_ARGS=()

ask_install_mode() {
  echo
  echo "参数模式："
  echo "1. 快速模式：密码/SSH端口/可选 hold1"
  echo "2. 高级模式：密码/公钥/Web端口/frpc/hold 等"
  read -r -p "请选择 [1-2，默认 1]: " mode
  mode="${mode:-1}"
  case "$mode" in
    2) PARAM_MODE="advanced" ;;
    *) PARAM_MODE="quick" ;;
  esac
}

ask_port() {
  local prompt="$1"
  local default="$2"
  local value=""
  while true; do
    read -r -p "$prompt [默认 $default]: " value
    value="${value:-$default}"
    if valid_port "$value"; then
      ASK_VALUE="$value"
      return 0
    fi
    warn "端口必须是 1-65535。"
  done
}

ask_optional_port() {
  local prompt="$1"
  local value=""
  while true; do
    read -r -p "$prompt [留空不设置]: " value
    if [ -z "$value" ]; then
      ASK_VALUE=""
      return 0
    fi
    if valid_port "$value"; then
      ASK_VALUE="$value"
      return 0
    fi
    warn "端口必须是 1-65535。"
  done
}

ask_password_to_array() {
  local arr="$1"
  local label="${2:-密码}"
  local allow_empty="${3:-true}"
  local pass=""
  read -r -s -p "请输入${label}${allow_empty:+ [留空跳过]}: " pass
  echo
  if [ -n "$pass" ]; then
    arr_add "$arr" --password "$pass"
  elif [ "$allow_empty" != "true" ]; then
    warn "密码为空，已跳过。"
  fi
}

ask_ssh_key_to_array() {
  local arr="$1"
  local key=""
  echo "SSH 公钥支持直接粘贴公钥，也可以填 URL / GitHub 用户名 / GitLab 用户名 / 本地路径。"
  read -r -p "请输入 SSH 公钥来源 [留空跳过]: " key
  [ -n "$key" ] && arr_add "$arr" --ssh-key "$key"
}

ask_login_opts() {
  local arr="$1"
  local subject="${2:-Linux root}"
  local login_mode=""

  echo
  echo "登录方式："
  echo "1. 设置 $subject 密码"
  echo "2. 使用 SSH 公钥"
  echo "3. 密码 + SSH 公钥"
  echo "4. 不设置，让原脚本提示或随机生成"
  read -r -p "请选择 [1-4，默认 1]: " login_mode
  login_mode="${login_mode:-1}"

  case "$login_mode" in
    1) ask_password_to_array "$arr" "$subject 密码" true ;;
    2) ask_ssh_key_to_array "$arr" ;;
    3)
      ask_password_to_array "$arr" "$subject 密码" true
      ask_ssh_key_to_array "$arr"
      ;;
    *) ;;
  esac
}

append_web_port_opts() {
  local arr="$1"
  ask_optional_port "Web 日志观察端口"
  [ -n "$ASK_VALUE" ] && arr_add "$arr" --web-port "$ASK_VALUE"
}

append_frpc_opts() {
  local arr="$1"
  local frpc_config=""
  read -r -p "frpc 配置文件路径/URL [留空不设置]: " frpc_config
  [ -n "$frpc_config" ] && arr_add "$arr" --frpc-config "$frpc_config"
}

append_hold_opts() {
  local arr="$1"
  local hold_mode=""
  echo
  echo "hold 模式："
  echo "0. 不使用"
  echo "1. 只进入安装环境，先验证 SSH/网络，不执行安装"
  echo "2. 安装结束后不自动重启，方便 SSH 检查"
  read -r -p "请选择 [0-2，默认 0]: " hold_mode
  hold_mode="${hold_mode:-0}"
  case "$hold_mode" in
    1) arr_add "$arr" --hold 1 ;;
    2) arr_add "$arr" --hold 2 ;;
    *) ;;
  esac
}

ask_common_linux_opts() {
  local mode="${1:-quick}"
  COMMON_ARGS=()

  ask_port "SSH 端口" "22"
  arr_add COMMON_ARGS --ssh-port "$ASK_VALUE"

  ask_login_opts COMMON_ARGS "root"

  if [ "$mode" = "advanced" ]; then
    append_web_port_opts COMMON_ARGS
    append_frpc_opts COMMON_ARGS
    append_hold_opts COMMON_ARGS
  else
    if ask_yes_no "是否先使用 hold1 进入安装环境验证网络？[y/N]: " "N"; then
      arr_add COMMON_ARGS --hold 1
    fi
  fi
}
