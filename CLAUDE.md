# Claude Code Notes

Follow the repository instructions in `AGENTS.md`.

Important local constraints:

- This is a local-only repository unless the user explicitly asks for GitHub or
  another remote.
- Keep the installer copy-based and offline-first.
- Use `bash script.sh` entrypoints; do not rely on executable bits being
  preserved by clone/copy/download workflows.
- `install.sh` runs `bash verify.sh` before writing to the real home unless
  `--skip-verify` is passed.
- Verification should cover the clone/copy install path and should not require
  release-zip tooling unless the distribution model changes.
- Default install must not create `~/.p10k.zsh`; let Powerlevel10k configure
  itself per machine unless the user explicitly passes a p10k profile option.
- Use Powerlevel10k only on zsh 5.1 or newer; older zsh should fall back to the
  bundled `gnzh` theme.
- Keep the Oh My Zsh cache/completions directory creation and permission
  hardening covered by verification.
- Keep secrets and machine-specific values out of tracked files.
- Use `zsh/.zshrc.local.example` for commented placeholders.
- Run the verification commands from `AGENTS.md` before reporting completion.
