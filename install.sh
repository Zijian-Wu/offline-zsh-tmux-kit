#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_HOME="${HOME:?HOME is required}"
BACKUP_DIR="$INSTALL_HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
ASSUME_YES=false
SKIP_VERIFY=false
P10K_PROFILE=none
OH_MY_ZSH_CACHE_DIR="$INSTALL_HOME/.cache/oh-my-zsh"
OH_MY_ZSH_COMPLETIONS_DIR="$OH_MY_ZSH_CACHE_DIR/completions"

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
  require_command find || missing=1
  require_command id || missing=1

  if [[ "$missing" -ne 0 ]]; then
    printf 'Install bash, zsh, tmux, git, and standard POSIX utilities first, then re-run this installer.\n' >&2
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
  require_path "$REPO_ROOT/vendors/oh-my-zsh/themes/gnzh.zsh-theme"
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

directory_has_group_or_other_write() {
  local path="$1"
  local insecure_path

  insecure_path="$(find -H "$path" -prune -type d -perm /022 -print 2>/dev/null || true)"
  if [[ -z "$insecure_path" ]]; then
    insecure_path="$(find -H "$path" -prune -type d -perm +022 -print 2>/dev/null || true)"
  fi

  [[ -n "$insecure_path" ]]
}

directory_owner_is_current_or_root() {
  local path="$1"
  local root_owned_path

  [[ -O "$path" ]] && return 0

  root_owned_path="$(find -H "$path" -prune -user 0 -print 2>/dev/null || true)"
  [[ -n "$root_owned_path" ]]
}

fix_directory_owner() {
  local path="$1"

  if directory_owner_is_current_or_root "$path"; then
    return 0
  fi

  if chown "$(id -u):$(id -g)" "$path" 2>/dev/null && directory_owner_is_current_or_root "$path"; then
    printf 'Fixed owner for %s\n' "$path"
    return 0
  fi

  printf 'Cannot secure %s: owner must be the current user or root.\n' "$path" >&2
  printf 'Fix it manually, for example: sudo chown "%s:%s" "%s"\n' "$(id -u)" "$(id -g)" "$path" >&2
  exit 1
}

harden_single_directory_permissions() {
  local path="$1"

  if directory_has_group_or_other_write "$path"; then
    if ! chmod go-w "$path" 2>/dev/null; then
      printf 'Cannot remove group/other write permission from %s.\n' "$path" >&2
      exit 1
    fi
  fi

  if directory_has_group_or_other_write "$path"; then
    printf 'Directory is still group/other-writable after hardening: %s\n' "$path" >&2
    exit 1
  fi
}

ensure_secure_directory() {
  local path="$1"

  mkdir -p "$path"
  fix_directory_owner "$path"
  harden_single_directory_permissions "$path"
}

ensure_oh_my_zsh_completion_cache() {
  local dir

  for dir in "$INSTALL_HOME/.cache" "$OH_MY_ZSH_CACHE_DIR" "$OH_MY_ZSH_COMPLETIONS_DIR"; do
    ensure_secure_directory "$dir"
  done

  printf 'Prepared Oh My Zsh completions cache at %s\n' "$OH_MY_ZSH_COMPLETIONS_DIR"
}

install_oh_my_zsh() {
  copy_dir "$REPO_ROOT/vendors/oh-my-zsh" "$INSTALL_HOME/.oh-my-zsh"
  mkdir -p "$INSTALL_HOME/.oh-my-zsh/custom/themes"
  mkdir -p "$INSTALL_HOME/.oh-my-zsh/custom/plugins"
  copy_dir "$REPO_ROOT/vendors/powerlevel10k" "$INSTALL_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
  copy_dir "$REPO_ROOT/vendors/zsh-autosuggestions" "$INSTALL_HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions"
  copy_dir "$REPO_ROOT/vendors/zsh-syntax-highlighting" "$INSTALL_HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting"
  harden_oh_my_zsh_directories
  ensure_oh_my_zsh_completion_cache
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
