#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
test_home="$(mktemp -d)"
tmux_socket="zsh_tmux_install_test_$$"
tmux_tmpdir="/tmp/ztmux-$$"
mkdir -p "$tmux_tmpdir"

remove_path() {
  local path="$1"
  local attempt

  [[ -e "$path" ]] || return 0

  for attempt in 1 2 3 4 5; do
    rm -rf "$path" 2>/dev/null && return 0
    sleep 0.1
  done

  rm -rf "$path"
}

cleanup() {
  TMUX_TMPDIR="$tmux_tmpdir" tmux -L "$tmux_socket" kill-server >/dev/null 2>&1 || true
  remove_path "$test_home"
  remove_path "$tmux_tmpdir"
}
trap cleanup EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f "$path" ]] || fail "expected file $path"
}

assert_dir() {
  local path="$1"
  [[ -d "$path" ]] || fail "expected directory $path"
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

(umask 0002; HOME="$test_home" "$repo_root/install.sh" --yes --skip-verify >"$test_home/install.log")

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

grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$test_home/.zshrc" ||
  fail "installed .zshrc does not enable powerlevel10k"

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

existing_p10k_home="$(mktemp -d)"
printf 'local p10k config\n' >"$existing_p10k_home/.p10k.zsh"
HOME="$existing_p10k_home" "$repo_root/install.sh" --yes --skip-verify >"$existing_p10k_home/install.log"
grep -qx 'local p10k config' "$existing_p10k_home/.p10k.zsh" ||
  fail "default install should preserve an existing .p10k.zsh"
remove_path "$existing_p10k_home"

p10k_home="$(mktemp -d)"
HOME="$p10k_home" "$repo_root/install.sh" --yes --skip-verify --p10k-profile nerdfont >"$p10k_home/install.log"
assert_file "$p10k_home/.p10k.zsh"
remove_path "$p10k_home"

release_zip="$test_home/offline-zsh-tmux-kit.zip"
release_dir="$test_home/release"
"$repo_root/tools/make-release-zip.sh" --output "$release_zip" >"$test_home/release.log"
assert_file "$release_zip"
mkdir -p "$release_dir"
unzip -q "$release_zip" -d "$release_dir"
release_root="$release_dir/offline-zsh-tmux-kit"
assert_file "$release_root/install.sh"
assert_file "$release_root/zsh/.zshrc"
assert_file "$release_root/tmux/.tmux.conf.local"
if find "$release_dir" -type l -print -quit | grep -q .; then
  fail "release zip should not contain symlinks"
fi
release_home="$(mktemp -d)"
HOME="$release_home" "$release_root/install.sh" --yes --skip-verify >"$release_home/install.log"
assert_file "$release_home/.zshrc"
assert_file "$release_home/.tmux.conf.local"
remove_path "$release_home"

printf 'PASS: verify\n'
