#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${REPO:-sockc/ddvps}"
BRANCH="${BRANCH:-main}"
BASE_URL="${BASE_URL:-https://raw.githubusercontent.com/${REPO}/${BRANCH}}"
INSTALL_DIR="${INSTALL_DIR:-/usr/local/share/ddvps}"
BIN="${BIN:-/usr/local/bin/ddvps}"

FILES=(
  "ddvps.sh"
  "lib/common.sh"
  "lib/detect.sh"
  "lib/input.sh"
  "lib/runner.sh"
  "lib/safety.sh"
  "menus/linux.sh"
  "menus/windows.sh"
  "menus/dd.sh"
  "menus/rescue.sh"
  "menus/manage.sh"
  "data/distros.conf"
  "data/windows.conf"
)

need_root() {
  if [ "$(id -u)" != "0" ]; then
    echo "请使用 root 用户运行。"
    exit 1
  fi
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

fetch() {
  local url="$1"
  local out="$2"
  mkdir -p "$(dirname "$out")"
  if has_cmd curl; then
    curl -fsSL --connect-timeout 10 --retry 2 -o "$out" "$url"
  elif has_cmd wget; then
    wget -qO "$out" "$url"
  else
    echo "未找到 curl 或 wget，无法下载文件。"
    exit 1
  fi
}

need_root
mkdir -p "$INSTALL_DIR"

echo "正在安装 DDVPS 菜单..."
echo "仓库: $REPO"
echo "分支: $BRANCH"
echo

for file in "${FILES[@]}"; do
  echo "下载: $file"
  fetch "$BASE_URL/$file" "$INSTALL_DIR/$file"
done

chmod +x "$INSTALL_DIR/ddvps.sh"
ln -sf "$INSTALL_DIR/ddvps.sh" "$BIN"

echo
echo "DDVPS 安装完成。"
echo "运行命令: ddvps"
echo "安装目录: $INSTALL_DIR"
