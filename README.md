# dotfiles

My macOS (Apple Silicon) development setup, bootstrapped with one idempotent script.

It installs [Homebrew](https://brew.sh), a small set of command-line tools, Node.js and Python, the [Starship](https://starship.rs) prompt, and two global git hooks that scan for secrets and enforce commit message conventions.

> **Note:** despite the name, this repo does not (yet) contain shell config files like `.zshrc`. The installer appends the lines it needs to your existing `~/.zprofile` and `~/.zshrc` instead of replacing them.

## Quick start

```bash
git clone https://github.com/methun-mohan/dotfiles.git ~/Development/dotfiles
cd ~/Development/dotfiles
./install.sh --check   # dry run: lists what's missing, changes nothing
./install.sh           # apply
```

Then open a **new** terminal tab so the changes load. The script is safe to re-run; every step checks before it acts.

## What's in here

| Path | Purpose |
| --- | --- |
| `install.sh` | The bootstrap script. Its header comment documents every step. |
| `Brewfile` | Single source of truth for every package and app that gets installed. |
| `githooks/pre-commit` | Runs [gitleaks](https://github.com/gitleaks/gitleaks) on staged changes and blocks commits containing secrets. |
| `githooks/commit-msg` | Enforces [Conventional Commits](https://www.conventionalcommits.org) (`feat: ...`, `fix(scope): ...`). |
| `LICENSE` | MIT. |

## What `install.sh` does

1. Verifies you're on Apple Silicon macOS (aborts otherwise).
2. Installs Homebrew using the official installer. It downloads the script, tells you where it is, and asks before running it. The installer also brings in the Xcode Command Line Tools.
3. Adds `brew shellenv` to `~/.zprofile`.
4. Runs `brew bundle` on the Brewfile, which installs:
   - **CLI tools:** `git`, `gh`, `jq`, `ripgrep`, `fd`, `starship`, `gitleaks`
   - **JavaScript:** `node`, `pnpm`
   - **Python:** `python`, `uv`
   - **Apps:** Visual Studio Code
5. Adds `eval "$(starship init zsh)"` to `~/.zshrc`.
6. Sets git's global `core.hooksPath` to this repo's `githooks/` folder.
7. Reminds you to set your git identity and run `gh auth login`. It never sets these for you.

Files it edits are backed up first (`<file>.bak.<timestamp>`), and lines are only appended if not already present.

## Git hooks

Because `core.hooksPath` is global, the hooks apply to **every** repository on the machine, not just this one.

- **Secret scan:** if `gitleaks` is missing, the hook warns and skips rather than blocking.
- **Commit messages:** the first line must match `type(optional-scope)!: summary` (summary up to 72 characters). Allowed types: `feat fix docs style refactor perf test build ci chore revert`. Merge, revert, `fixup!` and `squash!` messages pass through.
- **Bypass in an emergency:** `git commit --no-verify`.
- If you already have a `core.hooksPath` set, the installer will not overwrite it. It tells you instead.

To undo: `git config --global --unset core.hooksPath`.

## Staying up to date

Everything is managed by Homebrew, so one command keeps it all current:

```bash
brew update && brew upgrade && brew cleanup && brew autoremove
```

A few things to know:

- Homebrew's `node` follows the newest Node release (an LTS release as of Node 26). Check each spring that it's still LTS, or switch to a versioned formula such as `node@26`.
- A major Node or Python upgrade can require rebuilding `node_modules` or virtual environments.
- Use `uv` for Python virtual environments and tools rather than global `pip install`.
- Homebrew doesn't cover macOS itself (`softwareupdate -l`), global npm packages, or project dependencies. Audit those with each project's own tooling.

To add a tool, add it to the `Brewfile` and re-run `./install.sh`.

## Requirements and assumptions

- Apple Silicon Mac (Homebrew is expected at `/opt/homebrew`).
- zsh, the macOS default shell.
- Internet access for Homebrew and package downloads.

## License

[MIT](LICENSE)
