#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENDOR_DIR="$REPO_ROOT/vendors"
WORK_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
}

copy_vendor() {
  local name="$1"
  local url="$2"
  local branch="${3:-}"
  local clone_dir="$WORK_DIR/$name"
  local target_dir="$VENDOR_DIR/$name"

  printf 'Fetching %s from %s\n' "$name" "$url"
  if [[ -n "$branch" ]]; then
    git clone --depth 1 --branch "$branch" "$url" "$clone_dir"
  else
    git clone --depth 1 "$url" "$clone_dir"
  fi

  rm -rf "$target_dir"
  mkdir -p "$target_dir"
  tar --exclude='.git' -C "$clone_dir" -cf - . | tar -C "$target_dir" -xf -

  {
    printf '## %s\n\n' "$name"
    printf '- URL: `%s`\n' "$url"
    printf '- Commit: `%s`\n\n' "$(git -C "$clone_dir" rev-parse HEAD)"
  } >>"$WORK_DIR/VERSIONS.md"
}

main() {
  require_command git
  require_command tar

  mkdir -p "$VENDOR_DIR"
  printf '# Vendored Dependency Versions\n\n' >"$WORK_DIR/VERSIONS.md"

  copy_vendor oh-my-zsh https://github.com/ohmyzsh/ohmyzsh.git master
  copy_vendor powerlevel10k https://github.com/romkatv/powerlevel10k.git master
  copy_vendor zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions.git master
  copy_vendor zsh-syntax-highlighting https://github.com/zsh-users/zsh-syntax-highlighting.git master
  copy_vendor oh-my-tmux https://github.com/gpakosz/.tmux.git master

  mv "$WORK_DIR/VERSIONS.md" "$VENDOR_DIR/VERSIONS.md"
  printf 'Vendors updated in %s\n' "$VENDOR_DIR"
}

main "$@"
