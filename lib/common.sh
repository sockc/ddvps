#!/usr/bin/env bash

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

has_cmd() { command -v "$1" >/dev/null 2>&1; }

need_root() {
  if [ "$(id -u)" != "0" ]; then
    err "请使用 root 用户运行。"
    exit 1
  fi
}

arr_add() {
  local __arr="$1"
  shift
  local __item
  for __item in "$@"; do
    eval "$__arr+=(\"\$__item\")"
  done
}

is_uint() {
  [[ "${1:-}" =~ ^[0-9]+$ ]]
}

valid_port() {
  local p="${1:-}"
  is_uint "$p" && [ "$p" -ge 1 ] && [ "$p" -le 65535 ]
}

fetch_url() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  if has_cmd curl; then
    curl -fsSL --connect-timeout 10 --retry 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -qO "$out" "$url"
  else
    err "未找到 curl 或 wget，无法下载。"
    return 1
  fi
}

ask_yes_no() {
  local prompt="$1"
  local default="${2:-N}"
  local ans=""
  read -r -p "$prompt" ans
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy]$ ]]
}
