#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-sockc/ddvps}"
BRANCH="${BRANCH:-main}"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"

INSTALL_DIR="/usr/local/share/ddvps"
BIN="/usr/local/bin/ddvps"

if [ "$(id -u)" != "0" ]; then
  echo "请使用 root 用户运行。"
  exit 1
fi

mkdir -p "$INSTALL_DIR"

if command -v curl >/dev/null 2>&1; then
  curl -L -o "$INSTALL_DIR/ddvps.sh" "$BASE_URL/ddvps.sh"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$INSTALL_DIR/ddvps.sh" "$BASE_URL/ddvps.sh"
else
  echo "未找到 curl 或 wget"
  exit 1
fi

chmod +x "$INSTALL_DIR/ddvps.sh"
ln -sf "$INSTALL_DIR/ddvps.sh" "$BIN"

echo
echo "DDVPS 菜单安装完成。"
echo "运行命令：ddvps"
