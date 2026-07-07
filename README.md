# offline-zsh-tmux-kit

Offline-first, copy-mode Zsh and tmux setup. This repository vendors Oh My Zsh,
Powerlevel10k, common Zsh plugins, and gpakosz Oh my tmux so a machine can be
configured without network access after cloning or copying the repo.

## Included

- Oh My Zsh
- Powerlevel10k
- zsh-autosuggestions
- zsh-syntax-highlighting
- gpakosz Oh my tmux
- Portable Zsh and tmux config templates

## Requirements

Install these commands before running the installer:

- `bash`
- `zsh`
- `tmux`
- `git`

Powerlevel10k is used only when the runtime Zsh version is at least 5.1. Older
Zsh versions automatically use the bundled `gnzh` Oh My Zsh theme.

## Install

```bash
bash install.sh --yes
```

The installer runs `bash verify.sh` first, then copies files into `$HOME`. It
does not use symlinks. Existing files are moved to:

```text
~/.dotfiles-backup/YYYYmmdd-HHMMSS/
```

Installed paths:

```text
~/.zshrc
~/.zshrc.local
~/.oh-my-zsh/
~/.cache/oh-my-zsh/completions/
~/.tmux.conf
~/.tmux.conf.local
```

After installing Oh My Zsh, directory permissions are hardened to avoid
`compaudit` warnings in Docker, root, or group-writable `umask` environments.
The installer also creates `~/.cache/oh-my-zsh/completions/` and ensures
`~/.cache`, `~/.cache/oh-my-zsh`, and the completions directory are owned by the
current user or root and are not group/other-writable.

## Powerlevel10k

By default, the installer does not create `~/.p10k.zsh`. Powerlevel10k can run
its first-login wizard on each machine, which is safer when font and Unicode
support differ.

If `zsh` is older than 5.1, `~/.zshrc` skips Powerlevel10k and uses the bundled
`gnzh` theme instead.

For terminals known to support Nerd Font symbols:

```bash
bash install.sh --yes --p10k-profile nerdfont
```

The bundled profile is `zsh/p10k/nerdfont.zsh`.

## Local Config

Machine-specific settings belong in `~/.zshrc.local`, created from
`zsh/.zshrc.local.example` when missing. Keep real secrets, hostnames, private
paths, tokens, and proxy endpoints out of tracked files.

## Tmux

The main tmux config comes from Oh my tmux. Local overrides live in
`tmux/.tmux.conf.local`.

Reload an existing tmux server after installation:

```bash
tmux source-file ~/.tmux.conf
```

## Maintenance

Run verification manually without touching your real home:

```bash
bash verify.sh
```

Verification covers the clone/copy install path. This project does not require a
release zip build step.

Refresh vendored dependencies when network access is available:

```bash
bash update-vendors.sh
```

Vendored source trees are plain directories without nested `.git` metadata.

## Default shell

Make it your default shell: `chsh -s $(which zsh)`.

## Local user setup for Node.js/npm

See `local_npm.md` for details.
