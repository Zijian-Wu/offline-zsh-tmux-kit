# Agent Notes

This repository is an offline-first, copy-mode zsh and tmux setup. It is meant
to stay usable after a plain local clone with no network access.

## Ground Rules

- Keep all changes local unless the user explicitly asks for a remote, push, or
  GitHub action.
- Do not add a git remote or run `git push` without an explicit user request.
- Keep install behavior copy-based. Do not replace it with symlinks.
- Keep install and verification focused on plain clone/copy usage. Do not require
  release-archive tooling unless the distribution model changes.
- Do not install a Powerlevel10k profile by default. Default install should let
  Powerlevel10k run its first-login wizard for each machine.
- Do not copy real secrets, tokens, hostnames, private paths, or proxy endpoints
  into tracked files.
- Put machine-specific reminders in `zsh/.zshrc.local.example` as commented
  placeholders with empty or fake values.
- Treat `vendors/` as vendored third-party source. Do not hand-edit vendored
  files unless the user explicitly asks; refresh them with `update-vendors.sh`
  when network access is intended.
- Keep vendored source as plain directories without nested `.git` directories.
- Keep documentation lightweight. Prefer `README.md`, this `AGENTS.md`, and
  `CLAUDE.md` over generated planning docs.

## Repository Map

- `install.sh`: copy-mode installer for `$HOME`.
- `update-vendors.sh`: networked maintainer script to refresh `vendors/`.
- `zsh/.zshrc`: portable zsh config.
- `zsh/p10k/nerdfont.zsh`: optional powerlevel10k prompt config for Nerd Font
  terminals.
- `zsh/.zshrc.local.example`: commented local/private config template.
- `tmux/.tmux.conf.local`: gpakosz Oh my tmux local overrides.
- `vendors/`: offline dependency payload.
- `verify.sh`: installer verification using a temporary home directory.

## Safety Boundary

The parent directory may contain reference files such as `.zshrc`, `.tmux`,
`.tmux.conf`, and `.tmux.conf.local`. Treat them as read-only references. If a
value is machine-specific or sensitive, copy only its shape as a commented
placeholder into `zsh/.zshrc.local.example`.

Examples of values that must remain placeholders:

- `HF_TOKEN`
- API keys
- local conda paths
- CUDA version and path
- local proxy URLs
- company or server-specific flags

## Verification

Run these before claiming a change is complete:

```bash
./verify.sh
bash -n install.sh
bash -n update-vendors.sh
bash -n verify.sh
zsh -n zsh/.zshrc
zsh -n zsh/p10k/nerdfont.zsh
find vendors -name .git -type d -print
git ls-files -o -i --exclude-standard
```

The final two commands should print nothing.

For sensitive-value checks, use a targeted search like:

```bash
rg --hidden -g '!.git' -g '!AGENTS.md' -n 'hf_[A-Za-z0-9]{20,}|private-user|private-host|private-path|proxy-url' .
```

It should print nothing.

If ignored files appear unexpectedly, preview cleanup with:

```bash
git clean -ndX
```

Only run `git clean -fdX` after confirming the preview contains disposable
cache or generated files.
