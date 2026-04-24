#!/usr/bin/env bash

download_core() {
  info "正在下载原版 reinstall.sh ..."
  rm -f "$CORE"
  fetch_url "$UPSTREAM_REINSTALL_URL" "$CORE"
  if [ ! -s "$CORE" ]; then
    err "reinstall.sh 下载失败或文件为空。"
    return 1
  fi
  chmod +x "$CORE"
  info "原版 reinstall.sh 已下载到：$CORE"
}

render_download_steps() {
  if has_cmd curl; then
    printf 'curl -L -o %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
  else
    printf 'wget -O %q %q\n' "$CORE" "$UPSTREAM_REINSTALL_URL"
  fi
  printf 'chmod +x %q\n' "$CORE"
}

render_reinstall_cmd() {
  local mask="$1"
  shift
  local prev_password="0"
  local arg shown
  printf 'bash %q' "$CORE"
  for arg in "$@"; do
    shown="$arg"
    if [ "$mask" = "mask" ]; then
      if [ "$prev_password" = "1" ]; then
        shown="******"
        prev_password="0"
      elif [ "$arg" = "--password" ]; then
        prev_password="1"
      elif [[ "$arg" == --password=* ]]; then
        shown="--password=******"
      fi
    fi
    printf ' %q' "$shown"
  done
  echo
}

save_cmd_file() {
  local file="$1"
  local mask="$2"
  shift 2
  {
    echo "# 生成时间: $(date '+%F %T')"
    render_download_steps
    render_reinstall_cmd "$mask" "$@"
  } > "$file"
  chmod 600 "$file" 2>/dev/null || true
}

show_exec_cmd() {
  echo -e "${BLUE}即将生成/执行的命令：${PLAIN}"
  render_download_steps
  render_reinstall_cmd mask "$@"
}

run_or_print() {
  local args=("$@")

  echo
  show_exec_cmd "${args[@]}"
  echo
  save_cmd_file "$LAST_CMD_SAFE" mask "${args[@]}"
  info "已保存脱敏命令：$LAST_CMD_SAFE"
  warn "密码默认不会写入脱敏命令。需要完整命令时，请手动选择保存完整命令。"
  echo
  echo "1. 立即执行"
  echo "2. 只生成脱敏命令，不执行"
  echo "3. 保存完整命令，包含密码，不执行"
  echo "0. 取消"
  read -r -p "请选择 [0-3]: " act

  case "$act" in
    1)
      confirm_danger || return 0
      download_core
      info "开始执行 reinstall..."
      bash "$CORE" "${args[@]}"
      ;;
    2)
      info "已生成脱敏命令，不执行。"
      ;;
    3)
      save_cmd_file "$LAST_CMD_FULL" full "${args[@]}"
      info "已保存完整命令：$LAST_CMD_FULL"
      warn "该文件可能包含明文密码，权限已设置为 600。"
      ;;
    *)
      warn "已取消。"
      ;;
  esac
}
