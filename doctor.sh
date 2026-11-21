#!/usr/bin/env bash
# =============================================================================
# doctor.sh: check and upgrade the tools installed by install.sh.
#
# Usage:
#   ./doctor.sh                 # same as: ./doctor.sh status
#   ./doctor.sh status          # is anything stale? (outdated, missing, macOS)
#   ./doctor.sh versions        # installed versions of everything in Brewfile
#   ./doctor.sh info <pkg>      # latest version of one package, and ours
#   ./doctor.sh upgrade         # upgrade everything (brew AND pnpm), then clean up
#   ./doctor.sh upgrade <pkg>   # upgrade just one package (e.g. after a CVE)
#
# Two package managers are in play:
#   - Homebrew: everything in ./Brewfile.
#   - pnpm:     global CLIs in ./pnpm-globals.txt (e.g. the Pi coding agent).
#     Why pnpm: pi.dev documents npm/pnpm as the official install, and the brew
#     formula is community-maintained and can lag. `brew upgrade` does NOT touch
#     these, so ALWAYS update via `./doctor.sh upgrade` (or `pnpm update -g`).
#
# Homebrew has no built-in vulnerability scanner. Read the advisory, run
# `status` to see whether the fix has reached Homebrew, then `upgrade <pkg>`.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE="$SCRIPT_DIR/Brewfile"
PNPM_GLOBALS="$SCRIPT_DIR/pnpm-globals.txt"
BREW_BIN="/opt/homebrew/bin/brew"

say() { printf '\n==> %s\n' "$*"; }

[[ -x "$BREW_BIN" ]] && eval "$("$BREW_BIN" shellenv bash)"
if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Run ./install.sh first." >&2
  exit 1
fi

usage() { sed -n '2,/^# ====/p' "${BASH_SOURCE[0]}" | sed '1d;$d;s/^# \{0,1\}//'; }

# True when pnpm is present, its global bin dir is on PATH, and we have a list.
have_pnpm_globals() {
  [[ -f "$PNPM_GLOBALS" ]] && command -v pnpm >/dev/null 2>&1 && pnpm bin -g >/dev/null 2>&1
}

# Every formula and cask named in the Brewfile.
brewfile_packages() {
  brew bundle list --file="$BREWFILE" --formula
  brew bundle list --file="$BREWFILE" --cask
}

cmd_status() {
  say "Updating Homebrew's package list"
  brew update >/dev/null && echo "  done"

  say "Outdated packages (installed -> latest)"
  local outdated
  outdated="$(brew outdated --greedy --verbose)"
  [[ -n "$outdated" ]] && echo "$outdated" || echo "  ✔ everything is up to date"

  say "Brewfile packages not installed"
  brew bundle check --file="$BREWFILE" --verbose || true

  say "pnpm global tools (NOT covered by brew; update with ./doctor.sh upgrade)"
  if have_pnpm_globals; then
    # `pnpm outdated` exits non-zero when something is outdated, and prints
    # nothing when everything is current.
    local pnpm_outdated
    pnpm_outdated="$(pnpm outdated -g 2>&1 || true)"
    [[ -n "$pnpm_outdated" ]] && echo "$pnpm_outdated" || echo "  ✔ everything is up to date"
  else
    echo "  pnpm globals not set up. Run ./install.sh"
  fi

  say "macOS updates"
  softwareupdate -l 2>&1 | grep -v '^Software Update Tool$' || true

  say "brew doctor"
  brew doctor || true
}

cmd_versions() {
  say "Installed versions"
  # shellcheck disable=SC2046
  brew list --versions $(brewfile_packages)
  if have_pnpm_globals; then
    say "Installed versions (pnpm globals)"
    pnpm ls -g --depth=0
  fi
}

cmd_info() {
  [[ -n "${1:-}" ]] || { echo "Usage: ./doctor.sh info <pkg>" >&2; exit 1; }
  brew info "$1"
}

cmd_upgrade() {
  local pkg="${1:-}"
  say "Updating Homebrew's package list"
  brew update
  if [[ -n "$pkg" ]]; then
    if brew list "$pkg" >/dev/null 2>&1; then
      say "Upgrading $pkg (Homebrew)"
      brew upgrade "$pkg"
    elif have_pnpm_globals && pnpm ls -g --depth=0 2>/dev/null | grep -qF "$pkg"; then
      say "Upgrading $pkg (pnpm)"
      pnpm update -g --ignore-scripts "$pkg"
    else
      echo "'$pkg' is not installed by Homebrew or as a pnpm global." >&2
      exit 1
    fi
  else
    say "Upgrading everything (Homebrew)"
    brew upgrade
    say "Cleaning up"
    brew cleanup
    brew autoremove
    if have_pnpm_globals; then
      say "Upgrading pnpm global tools"
      pnpm update -g --ignore-scripts
    fi
  fi
}

case "${1:-status}" in
  status)           cmd_status ;;
  versions)         cmd_versions ;;
  info)             shift; cmd_info "$@" ;;
  upgrade)          shift; cmd_upgrade "$@" ;;
  -h|--help|help)   usage ;;
  *) echo "Unknown command: $1" >&2; usage >&2; exit 1 ;;
esac
