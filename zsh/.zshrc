# Enable Powerlevel10k instant prompt. Keep this near the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="${ZSH:-$HOME/.oh-my-zsh}"
export ZSH_CUSTOM="${ZSH_CUSTOM:-$ZSH/custom}"

ZSH_THEME="powerlevel10k/powerlevel10k"

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

[[ ! -f "$HOME/.p10k.zsh" ]] || source "$HOME/.p10k.zsh"
[[ ! -f "$HOME/.zshrc.local" ]] || source "$HOME/.zshrc.local"
