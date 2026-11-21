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
| `doctor.sh` | Day-to-day checks and upgrades: what's outdated, installed versions, patch one package. |
| `Brewfile` | Single source of truth for every package and app that gets installed. |
| `pnpm-globals.txt` | Global CLI tools installed with pnpm instead of brew (currently the Pi coding agent, pi.dev). |
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

`doctor.sh` is the day-to-day companion to `install.sh`. It reads the same Brewfile.

| Command | What it does |
| --- | --- |
| `./doctor.sh` or `./doctor.sh status` | Refreshes Homebrew, then lists outdated packages, anything missing from the Brewfile, pending macOS updates, and `brew doctor` warnings. |
| `./doctor.sh versions` | Installed version of every package in the Brewfile. |
| `./doctor.sh info <pkg>` | Latest version of one package and whether you have it (e.g. `./doctor.sh info node`). |
| `./doctor.sh upgrade` | Upgrades everything (Homebrew, then pnpm globals), then runs `brew cleanup` and `brew autoremove`. |
| `./doctor.sh upgrade <pkg>` | Upgrades just one package. |

**Heard about a vulnerability?** Homebrew has no built-in vulnerability scanner, so start from the advisory. Run `./doctor.sh status` to see whether the fix has reached Homebrew yet. If it has, `./doctor.sh upgrade <pkg>` patches it. Homebrew can trail upstream releases by a few days.

A few things to know:

- Homebrew's `node` follows the newest Node release (an LTS release as of Node 26). Check each spring that it's still LTS, or switch to a versioned formula such as `node@26`.
- A major Node or Python upgrade can require rebuilding `node_modules` or virtual environments.
- Use `uv` for Python virtual environments and tools rather than global `pip install`.
- Homebrew doesn't cover macOS itself (`doctor.sh status` lists pending updates, but install them in System Settings), global npm packages, or project dependencies. Audit those with each project's own tooling.

To add a tool, add it to the `Brewfile` and re-run `./install.sh`.

**pnpm-managed tools (remember to update these with pnpm).** The Pi coding agent is installed with pnpm, not brew: pi.dev documents npm/pnpm as its official install, and the Homebrew formula is community-maintained and can lag new releases. `brew upgrade` does not touch it. Update with `./doctor.sh upgrade` (which runs `pnpm update -g`), or directly with `pnpm update -g`. `./doctor.sh status` lists outdated pnpm globals. To add another pnpm tool, add its package name to `pnpm-globals.txt` and re-run `./install.sh`.

## Requirements and assumptions

- Apple Silicon Mac (Homebrew is expected at `/opt/homebrew`).
- zsh, the macOS default shell.
- Internet access for Homebrew and package downloads.

## License

[MIT](LICENSE)
