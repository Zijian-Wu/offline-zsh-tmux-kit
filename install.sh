#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_HOME="${HOME:?HOME is required}"
BACKUP_DIR="$INSTALL_HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=false
SKIP_VERIFY=false
P10K_PROFILE=none

usage() {
  cat <<'USAGE'
Usage: bash install.sh [--yes] [--skip-verify] [--p10k-profile none|nerdfont]

Copy the vendored zsh/tmux environment into $HOME.

Options:
  --yes                       run non-interactively
  --skip-verify               skip the pre-install verification step
  --p10k-profile none|nerdfont
                              install an optional Powerlevel10k config
  -h,--help                   show this help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y)
      ASSUME_YES=true
      ;;
    --skip-verify)
      SKIP_VERIFY=true
      ;;
    --p10k-profile)
      if [[ $# -lt 2 ]]; then
        printf 'Missing value for --p10k-profile\n' >&2
        usage >&2
        exit 2
      fi
      P10K_PROFILE="$2"
      shift
      ;;
    --p10k-profile=*)
      P10K_PROFILE="${1#*=}"
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

case "$P10K_PROFILE" in
  none|nerdfont)
    ;;
  *)
    printf 'Unsupported --p10k-profile: %s\n' "$P10K_PROFILE" >&2
    usage >&2
    exit 2
    ;;
esac

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "$command_name" >&2
    return 1
  fi
}

check_required_commands() {
  local missing=0
  require_command bash || missing=1
  require_command zsh || missing=1
  require_command tmux || missing=1
  require_command git || missing=1

  if [[ "$missing" -ne 0 ]]; then
    printf 'Install bash, zsh, tmux, and git first, then re-run this installer.\n' >&2
    exit 1
  fi
}

require_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'Required repository path is missing: %s\n' "$path" >&2
    exit 1
  fi
}

check_repository_payload() {
  require_path "$REPO_ROOT/vendors/oh-my-zsh/oh-my-zsh.sh"
  require_path "$REPO_ROOT/vendors/powerlevel10k/powerlevel10k.zsh-theme"
  require_path "$REPO_ROOT/vendors/zsh-autosuggestions/zsh-autosuggestions.zsh"
  require_path "$REPO_ROOT/vendors/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  require_path "$REPO_ROOT/vendors/oh-my-tmux/.tmux.conf"
  require_path "$REPO_ROOT/zsh/.zshrc"
  require_path "$REPO_ROOT/zsh/.zshrc.local.example"
  require_path "$REPO_ROOT/tmux/.tmux.conf.local"

  if [[ "$P10K_PROFILE" == nerdfont ]]; then
    require_path "$REPO_ROOT/zsh/p10k/nerdfont.zsh"
  fi
}

run_preinstall_verify() {
  if [[ "$SKIP_VERIFY" == true ]]; then
    return
  fi

  require_path "$REPO_ROOT/verify.sh"
  printf 'Running pre-install verification...\n'
  bash "$REPO_ROOT/verify.sh"
}

confirm_install() {
  if [[ "$ASSUME_YES" == true ]]; then
    return
  fi

  cat <<EOF
This will copy zsh and tmux config into:
  $INSTALL_HOME/.zshrc
  $INSTALL_HOME/.oh-my-zsh
  $INSTALL_HOME/.tmux.conf
  $INSTALL_HOME/.tmux.conf.local

Existing files will be backed up under:
  $BACKUP_DIR
EOF

  printf 'Continue? [y/N] '
  read -r answer
  case "$answer" in
    y|Y|yes|YES)
      ;;
    *)
      printf 'Install cancelled.\n'
      exit 0
      ;;
  esac
}

ensure_backup_dir() {
  mkdir -p "$BACKUP_DIR"
}

backup_path() {
  local target="$1"
  local name
  name="$(basename "$target")"

  if [[ -e "$target" || -L "$target" ]]; then
    ensure_backup_dir
    mv "$target" "$BACKUP_DIR/$name"
    printf 'Backed up %s -> %s\n' "$target" "$BACKUP_DIR/$name"
  fi
}

copy_file() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  backup_path "$target"
  cp "$source" "$target"
  printf 'Installed %s\n' "$target"
}

copy_dir() {
  local source="$1"
  local target="$2"
  mkdir -p "$(dirname "$target")"
  backup_path "$target"
  cp -R "$source" "$target"
  printf 'Installed %s\n' "$target"
}

harden_oh_my_zsh_directories() {
  local zsh_dir="$INSTALL_HOME/.oh-my-zsh"

  [[ -d "$zsh_dir" ]] || return 0

  find "$zsh_dir" -type d -exec chmod go-w {} +
  printf 'Hardened Oh My Zsh directory permissions under %s\n' "$zsh_dir"
}

install_oh_my_zsh() {
  copy_dir "$REPO_ROOT/vendors/oh-my-zsh" "$INSTALL_HOME/.oh-my-zsh"
  mkdir -p "$INSTALL_HOME/.oh-my-zsh/custom/themes"
  mkdir -p "$INSTALL_HOME/.oh-my-zsh/custom/plugins"
  copy_dir "$REPO_ROOT/vendors/powerlevel10k" "$INSTALL_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  copy_dir "$REPO_ROOT/vendors/zsh-autosuggestions" "$INSTALL_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  copy_dir "$REPO_ROOT/vendors/zsh-syntax-highlighting" "$INSTALL_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  harden_oh_my_zsh_directories
}

install_tmux() {
  copy_file "$REPO_ROOT/vendors/oh-my-tmux/.tmux.conf" "$INSTALL_HOME/.tmux.conf"
  copy_file "$REPO_ROOT/tmux/.tmux.conf.local" "$INSTALL_HOME/.tmux.conf.local"
}

install_zsh_config() {
  copy_file "$REPO_ROOT/zsh/.zshrc" "$INSTALL_HOME/.zshrc"

  case "$P10K_PROFILE" in
    none)
      printf 'Skipped %s so Powerlevel10k can run its first-login wizard.\n' "$INSTALL_HOME/.p10k.zsh"
      ;;
    nerdfont)
      copy_file "$REPO_ROOT/zsh/p10k/nerdfont.zsh" "$INSTALL_HOME/.p10k.zsh"
      ;;
  esac

  if [[ ! -e "$INSTALL_HOME/.zshrc.local" && ! -L "$INSTALL_HOME/.zshrc.local" ]]; then
    cp "$REPO_ROOT/zsh/.zshrc.local.example" "$INSTALL_HOME/.zshrc.local"
    printf 'Created %s\n' "$INSTALL_HOME/.zshrc.local"
  else
    printf 'Kept existing %s\n' "$INSTALL_HOME/.zshrc.local"
  fi
}

main() {
  check_required_commands
  check_repository_payload
  run_preinstall_verify
  confirm_install
  install_oh_my_zsh
  install_tmux
  install_zsh_config

  cat <<EOF

Install complete.

Next steps:
  1. Restart your terminal or run: exec zsh
  2. If zsh is not your login shell, run: chsh -s "\$(command -v zsh)"
  3. For an existing tmux server, reload with: tmux source-file ~/.tmux.conf

Machine-specific config belongs in:
  $INSTALL_HOME/.zshrc.local
EOF
}

main "$@"
