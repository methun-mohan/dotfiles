#!/usr/bin/env bash
# =============================================================================
# install.sh: macOS (Apple Silicon) dev setup. Code and documentation in one.
#
# What it does, in order (each step checks first, so re-running is safe):
#   1. Confirms you're on an Apple Silicon Mac.
#   2. Installs Homebrew (official installer, downloaded and shown to you first).
#      The Homebrew installer also installs the Xcode Command Line Tools.
#   3. Puts brew on your PATH via ~/.zprofile.
#   4. Installs everything in ./Brewfile (the single source of truth for
#      packages) with `brew bundle`.
#   5. Enables the Starship prompt via ~/.zshrc (zsh init, NOT bash).
#   6. Points git at the hooks in ./githooks (global core.hooksPath):
#        - pre-commit: gitleaks scans staged changes for secrets
#        - commit-msg: enforces Conventional Commits (feat: ..., fix: ...)
#      Bypass in an emergency with: git commit --no-verify
#   7. Reminds you about git identity and GitHub login (never sets them for you).
#
# Usage:
#   ./install.sh --check   # report what's missing, change nothing
#   ./install.sh           # do the work
#
# Lessons baked in from the first run:
#   - `brew: command not found` after install = PATH not set (step 3).
#   - Prompt showing literal \[ \] = used `starship init bash` in zsh (step 5).
#   - `eval` typed in a terminal only lasts for that window; it must live in
#     ~/.zshrc to persist.
#   - Package name != command name (ripgrep installs `rg`).
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/githooks"
BREWFILE="$SCRIPT_DIR/Brewfile"
BREW_BIN="/opt/homebrew/bin/brew"
BREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
ZPROFILE="$HOME/.zprofile"
ZSHRC="$HOME/.zshrc"
BREW_LINE='eval "$(/opt/homebrew/bin/brew shellenv zsh)"'
STARSHIP_LINE='eval "$(starship init zsh)"'

CHECK_ONLY=false
[[ "${1:-}" == "--check" ]] && CHECK_ONLY=true
TODO_COUNT=0

say()  { printf '\n==> %s\n' "$*"; }
ok()   { printf '  ✔ %s\n' "$*"; }
todo() { printf '  • %s\n' "$*"; TODO_COUNT=$((TODO_COUNT + 1)); }

# Append a line to a file only if it isn't already there (exact match).
# Backs the file up once per run before the first change.
append_once() {
  local file="$1" line="$2"
  if [[ -f "$file" ]] && grep -qxF "$line" "$file"; then
    ok "$file already contains: $line"
  elif $CHECK_ONLY; then
    todo "add to $file: $line"
  else
    [[ -f "$file" ]] && cp "$file" "$file.bak.$(date +%Y%m%d%H%M%S)"
    printf '\n%s\n' "$line" >> "$file"
    ok "added to $file: $line"
  fi
}

# ---- 1. Platform check -------------------------------------------------------
say "Checking platform"
if [[ "$(uname -s)" != "Darwin" || "$(uname -m)" != "arm64" ]]; then
  echo "This script targets Apple Silicon macOS only. Aborting." >&2
  exit 1
fi
ok "Apple Silicon macOS"

# ---- 2. Homebrew -------------------------------------------------------------
say "Checking Homebrew"
if [[ -x "$BREW_BIN" ]]; then
  ok "Homebrew installed ($("$BREW_BIN" --version | head -n1))"
elif $CHECK_ONLY; then
  todo "install Homebrew"
else
  tmp="$(mktemp)"
  curl -fsSL "$BREW_INSTALL_URL" -o "$tmp"
  echo "  Downloaded the official Homebrew installer to: $tmp"
  echo "  Review it now if you want (e.g. open it in an editor)."
  read -r -p "  Run it? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || { echo "Aborted by user."; exit 1; }
  /bin/bash "$tmp"
  rm -f "$tmp"
fi

# ---- 3. PATH -----------------------------------------------------------------
say "Checking PATH setup (~/.zprofile)"
append_once "$ZPROFILE" "$BREW_LINE"
# Make brew available to the rest of this script run.
[[ -x "$BREW_BIN" ]] && eval "$("$BREW_BIN" shellenv bash)"

# ---- 4. Packages (from Brewfile) ---------------------------------------------
say "Checking packages in Brewfile"
if [[ ! -f "$BREWFILE" ]]; then
  todo "Brewfile missing next to install.sh"
elif ! command -v brew >/dev/null 2>&1; then
  todo "install packages (needs Homebrew first)"
elif brew bundle check --file="$BREWFILE" >/dev/null 2>&1; then
  ok "everything in Brewfile is installed"
elif $CHECK_ONLY; then
  todo "install missing packages: brew bundle --file=Brewfile"
  brew bundle check --file="$BREWFILE" --verbose || true
else
  brew bundle install --file="$BREWFILE"
fi

# ---- 5. Starship prompt ------------------------------------------------------
say "Checking Starship prompt (~/.zshrc)"
append_once "$ZSHRC" "$STARSHIP_LINE"
if [[ -f "$ZSHRC" ]] && grep -Eq 'starship init (bash|fish)' "$ZSHRC"; then
  todo "$ZSHRC has a bash/fish Starship line; remove it (zsh needs 'init zsh')"
fi

# Running the bare macOS `git` shim before the Command Line Tools exist pops up
# an install dialog, so only touch git once a real one is present.
git_usable() { xcode-select -p >/dev/null 2>&1 || [[ -x /opt/homebrew/bin/git ]]; }

# ---- 6. Git hooks (secret scan + commit message convention) ------------------
say "Checking git hooks (global core.hooksPath -> $HOOKS_DIR)"
if [[ ! -d "$HOOKS_DIR" ]]; then
  todo "githooks/ folder missing next to install.sh"
elif ! git_usable; then
  todo "hooks need git; run again after Homebrew/git are installed"
else
  current_hooks="$(git config --global core.hooksPath || true)"
  if [[ "$current_hooks" == "$HOOKS_DIR" ]]; then
    ok "core.hooksPath already set"
  elif [[ -n "$current_hooks" ]]; then
    todo "core.hooksPath is already '$current_hooks'; not overwriting (set it yourself if intended)"
  elif $CHECK_ONLY; then
    todo "set core.hooksPath to $HOOKS_DIR"
  else
    chmod +x "$HOOKS_DIR"/*
    git config --global core.hooksPath "$HOOKS_DIR"
    ok "core.hooksPath set to $HOOKS_DIR"
  fi
fi

# ---- 7. Reminders (never changed automatically) ------------------------------
say "Checking git identity and GitHub login"
if git_usable; then
  [[ -n "$(git config --global user.name  || true)" ]] && ok "git user.name set"  || todo 'git config --global user.name "Your Name"'
  [[ -n "$(git config --global user.email || true)" ]] && ok "git user.email set" || todo 'git config --global user.email "you@example.com"'
fi
if command -v gh >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 && ok "gh authenticated" || todo "run: gh auth login"
fi

# ---- Summary -----------------------------------------------------------------
say "Done"
if $CHECK_ONLY; then
  echo "  $TODO_COUNT item(s) need attention. Run ./install.sh to apply."
else
  echo "  Open a NEW terminal tab to load the changes."
  [[ $TODO_COUNT -gt 0 ]] && echo "  $TODO_COUNT manual item(s) listed above."
fi
echo "  Weekly upkeep: brew update && brew upgrade"
