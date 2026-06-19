#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
temp_paths=()
tmux_socket="zsh_tmux_install_test_$$"
tmux_tmpdir=""
test_home=""

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    return 1
  fi
}

check_required_commands() {
  local missing=0
  local command_name

  for command_name in bash find git grep id mktemp tmux zsh; do
    require_command "$command_name" || missing=1
  done

  if [[ "$missing" -ne 0 ]]; then
    fail "install required commands before running verification"
  fi
}

remove_path() {
  local path="$1"
  local attempt

  [[ -e "$path" || -L "$path" ]] || return 0

  for attempt in 1 2 3 4 5; do
    rm -rf "$path" 2>/dev/null && return 0
    sleep 0.1
  done

  rm -rf "$path"
}

cleanup() {
  local path

  if [[ -n "${tmux_tmpdir:-}" && -d "$tmux_tmpdir" ]] && command -v tmux >/dev/null 2>&1; then
    TMUX_TMPDIR="$tmux_tmpdir" tmux -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  fi

  for path in "${temp_paths[@]:-}"; do
    remove_path "$path"
  done
}
trap cleanup EXIT

make_temp_dir() {
  local result_var="$1"
  local dir

  dir="$(mktemp -d)"
  temp_paths+=("$dir")
  printf -v "$result_var" '%s' "$dir"
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file $path"
}

assert_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory $path"
}

assert_owner_current_or_root() {
  local path="$1"
  local root_owned_path

  [[ -O "$path" ]] && return 0

  root_owned_path="$(find -H "$path" -prune -user 0 -print 2>/dev/null || true)"
  [[ -n "$root_owned_path" ]] || fail "expected $path to be owned by the current user or root"
}

assert_no_group_or_other_writable_dirs() {
  local path="$1"
  local insecure_path

  insecure_path="$(find "$path" -type d -perm /022 -print -quit 2>/dev/null || true)"
  if [[ -z "$insecure_path" ]]; then
    insecure_path="$(find "$path" -type d -perm +022 -print -quit 2>/dev/null || true)"
  fi

  [[ -z "$insecure_path" ]] ||
    fail "expected no group/other-writable directories under $path, found $insecure_path"
}

check_required_commands
make_temp_dir tmux_tmpdir
make_temp_dir test_home

(umask 0002; HOME="$test_home" bash "$repo_root/install.sh" --yes --skip-verify >"$test_home/install.log")

assert_file "$test_home/.zshrc"
assert_file "$test_home/.zshrc.local"
assert_file "$test_home/.tmux.conf"
assert_file "$test_home/.tmux.conf.local"

if [[ -e "$test_home/.p10k.zsh" || -L "$test_home/.p10k.zsh" ]]; then
  fail "default install should let powerlevel10k configure itself, not install .p10k.zsh"
fi

assert_dir "$test_home/.oh-my-zsh"
assert_dir "$test_home/.oh-my-zsh/custom/themes/powerlevel10k"
assert_dir "$test_home/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
assert_dir "$test_home/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
assert_no_group_or_other_writable_dirs "$test_home/.oh-my-zsh/custom"

assert_dir "$test_home/.cache"
assert_dir "$test_home/.cache/oh-my-zsh"
assert_dir "$test_home/.cache/oh-my-zsh/completions"
assert_owner_current_or_root "$test_home/.cache"
assert_owner_current_or_root "$test_home/.cache/oh-my-zsh"
assert_owner_current_or_root "$test_home/.cache/oh-my-zsh/completions"
assert_no_group_or_other_writable_dirs "$test_home/.cache"

grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$test_home/.zshrc" ||
  fail "installed .zshrc does not enable powerlevel10k"

grep -q 'ZSH_THEME="gnzh"' "$test_home/.zshrc" ||
  fail "installed .zshrc does not include the zsh<5.1 gnzh fallback theme"

grep -q 'is-at-least 5.1' "$test_home/.zshrc" ||
  fail "installed .zshrc does not check the Powerlevel10k zsh version requirement"

grep -q 'ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}"' "$test_home/.zshrc" ||
  fail "installed .zshrc does not set the Oh My Zsh cache directory"

grep -q 'zsh-autosuggestions' "$test_home/.zshrc" ||
  fail "installed .zshrc does not enable zsh-autosuggestions"

grep -q 'zsh-syntax-highlighting' "$test_home/.zshrc" ||
  fail "installed .zshrc does not enable zsh-syntax-highlighting"

tmux_output="$test_home/tmux-start.log"
if ! HOME="$test_home" TMUX_TMPDIR="$tmux_tmpdir" tmux -L "$tmux_socket" -f "$test_home/.tmux.conf" new-session -d true >"$tmux_output" 2>&1; then
  cat "$tmux_output" >&2
  fail "tmux could not start with installed config"
fi

unexpected_tmux_output="$test_home/tmux-unexpected.log"
grep -vE '^error creating .+ \(Operation not permitted\)$' "$tmux_output" >"$unexpected_tmux_output" || true
if [[ -s "$unexpected_tmux_output" ]]; then
  cat "$unexpected_tmux_output" >&2
  fail "tmux started with unexpected output"
fi

make_temp_dir existing_p10k_home
printf 'local p10k config\n' >"$existing_p10k_home/.p10k.zsh"
HOME="$existing_p10k_home" bash "$repo_root/install.sh" --yes --skip-verify >"$existing_p10k_home/install.log"
grep -qx 'local p10k config' "$existing_p10k_home/.p10k.zsh" ||
  fail "default install should preserve an existing .p10k.zsh"

make_temp_dir p10k_home
HOME="$p10k_home" bash "$repo_root/install.sh" --yes --skip-verify --p10k-profile nerdfont >"$p10k_home/install.log"
assert_file "$p10k_home/.p10k.zsh"

printf 'PASS: verify\n'
