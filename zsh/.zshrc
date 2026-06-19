# Enable Powerlevel10k instant prompt. Keep this near the top of ~/.zshrc.
autoload -Uz is-at-least

offline_zsh_supports_powerlevel10k() {
  is-at-least 5.1 "${ZSH_VERSION:-0}"
}

if offline_zsh_supports_powerlevel10k; then
  if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
  fi
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"
export ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-$HOME/.cache/oh-my-zsh}"

if offline_zsh_supports_powerlevel10k; then
  ZSH_THEME="powerlevel10k/powerlevel10k"
else
  ZSH_THEME="gnzh"
fi

zstyle ':omz:update' mode disabled
DISABLE_AUTO_TITLE="true"

plugins=(
  git
  z
  tmux
  zsh-autosuggestions
  zsh-syntax-highlighting
)

if [[ -r "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  print -u2 "oh-my-zsh not found at $ZSH. Run the dotfiles installer again."
fi

alias c='clear'

export PATH="$HOME/.local/bin:$PATH"

if offline_zsh_supports_powerlevel10k; then
  [[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
fi
[[ ! -f "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"
