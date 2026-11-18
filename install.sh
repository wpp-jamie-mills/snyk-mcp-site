#!/bin/bash
# AUTO-GENERATED: Published to GitHub Pages by CI on each tagged release.
# Do not edit the published copy — edit install.sh in the snyk-mcp repository instead.
#
# Installs the latest Snyk Projects and Issues (unofficial) extension (.mcpb) into Claude Desktop (macOS).
#   curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash
# For an AI agent or a script (no terminal: it never prompts, and doesn't wait for the install dialog):
#   curl -fsSL <same url> | SNYK_INSTALL_TTY=/dev/null bash -s -- --no-wait
# When the organisation blocks the extension, the same release as a Claude Desktop mcpServers entry (needs uv):
#   curl -fsSL <same url> | bash -s -- --entry
#
# Environment overrides (mainly for tests):
#   SNYK_MCP_HOME           download folder (--dir wins; default ~/.snyk-mcp)
#   SNYK_INSTALL_BASE       base URL for the download files (default: the GitHub Pages site)
#   SNYK_INSTALL_TTY        where questions are read from (default /dev/tty; /dev/null = no terminal)
#   SNYK_CLAUDE_APP         path to Claude.app (default /Applications/Claude.app)
#   SNYK_INSTALL_NO_OPEN    1 = don't open Claude Desktop (its install dialog, or the app for --entry); just say
#                              what would happen
#   SNYK_INSTALL_WAIT_SECS  how long to wait for the extension (or the entry) to be installed and running
#                              (default 600; 0 with --no-wait or SNYK_INSTALL_NO_OPEN=1)
#   SNYK_INSTALL_SETTLE_SECS  after that, how long to wait before checking it is still there (default 5)
#   SNYK_INSTALL_API_HOSTS     Snyk API hosts to try the token against (default: api.snyk.io api.eu.snyk.io
#                              api.au.snyk.io api.us.snyk.io); SNYK_INSTALL_API_SCHEME (default https) for tests
#   SNYK_INSTALL_UV         where to look for uv, as a colon-separated list (default: uv on PATH, then
#                              /opt/homebrew/bin/uv, /usr/local/bin/uv, ~/.local/bin/uv); empty = nowhere
#   SNYK_INSTALL_BREW       Homebrew's brew for installing uv (default: brew on PATH or in /opt/homebrew or
#                              /usr/local); empty = no Homebrew
#   SNYK_INSTALL_UV_BASE    where uv's release tarballs are downloaded from (default: its GitHub release)
#   SNYK_INSTALL_UV_SHA256  the tarball's expected SHA-256 instead of the pinned one (for testing)
#   SNYK_MCP_DATA_DIR       the server's data folder, as the server reads it (default
#                              ~/Library/Application Support/snyk-mcp); --entry installs into its server folder
set -euo pipefail

# Default download base (the prerelease copy is rewritten to point at /rc). Exactly one such line.
SITE_BASE_DEFAULT="https://wpp-jamie-mills.github.io/snyk-mcp-site"
# The stable site, also from the prerelease copy (where --entry is refused: the entry installs stable releases only).
SITE_BASE_STABLE="${SITE_BASE_DEFAULT%/rc}"

APP_TITLE="Snyk Projects and Issues (unofficial)"
# The oldest Claude Desktop the extension supports (manifest.json compatibility.claude_desktop).
MIN_CLAUDE_VERSION="2.7032.0"
# The Keychain item holding the saved Snyk token (snyk_mcp/token_store.py SERVICE); the installer writes it through
# `security -i` on stdin and --status only checks that it is there.
KEYCHAIN_SERVICE="snyk-mcp-pat"
# The Keychain accounts: the token itself, and the region host it works on (not a secret).
KEYCHAIN_TOKEN_ACCOUNT="default"
KEYCHAIN_HOST_ACCOUNT="host"
# --entry: the mcpServers entry's name in claude_desktop_config.json (Claude Desktop names its log after it), and
# the command `snyk-mcp install-release` writes in <data folder>/server (snyk_mcp/managed.py LAUNCHER_NAME).
ENTRY_NAME="snyk-mcp"
LAUNCHER_NAME="snyk-mcp"
# The line of `snyk-mcp install-release` that says where that command is (snyk_mcp/managed.py ENTRY_COMMAND_LABEL).
ENTRY_COMMAND_LABEL="Claude Desktop entry command:"
# The entry runs with uv. When it is missing and the owner agrees (or --install-uv), the installer installs it: with
# Homebrew when there is one, else this uv release from GitHub, checked against its published SHA-256 (pinned here),
# into ~/.local/bin. The same version as CI's (.github/workflows/mcpb.yml setup-uv).
UV_VERSION="0.12.18"
UV_SHA256_AARCH64="cf40e0c6a202190ccd9e0406dcfdd5b2d6668a9a5c779b17948963df32aafe5b"
UV_SHA256_X86_64="2e4108f5395397c8bc5d43bf83d3bdbb2d0e92b90d0efa607756be704905fa33"

# Colour only on a terminal, so agent and CI logs stay plain.
if [[ -t 1 && -t 2 ]]; then
  RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' BLUE='\033[0;34m' NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' NC=''
fi

# printf, not echo -e, so backslashes in paths are shown as typed.
print_error() { printf '%b✗ %s%b\n' "$RED" "$1" "$NC" >&2; }
print_success() { printf '%b✓ %s%b\n' "$GREEN" "$1" "$NC"; }
print_warning() { printf '%b⚠ %s%b\n' "$YELLOW" "$1" "$NC"; }
print_step() { printf '%b→ %s%b\n' "$BLUE" "$1" "$NC"; }
die() {
  print_error "$1"
  exit 1
}

SNYK_TEMP_DIR=""
cleanup_temp() {
  if [[ -n "$SNYK_TEMP_DIR" && -d "$SNYK_TEMP_DIR" ]]; then rm -rf "$SNYK_TEMP_DIR"; fi
}

usage() {
  cat <<'EOF'
Snyk Projects and Issues (unofficial) installer (macOS, Claude Desktop)

Usage:
  curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash
  curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash -s -- --status
  curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash -s -- --entry

It downloads the latest extension (.mcpb), checks its SHA-256 before anything changes, opens Claude Desktop's
install dialog, and waits until the extension is installed, switched on and running. Click Install there. Running
it again updates the extension and keeps your settings and your Snyk token. The first time it asks for your Snyk
token (hidden input) and keeps it in your macOS Keychain only.

Options:
  --dir <path>   Folder for the downloaded extension (default: ~/.snyk-mcp).
  --status       Print what is installed (download, Claude Desktop, uv, the extension and whether it is switched
                 on or blocked by your organisation, write tools, the mcpServers entry, whether the server is
                 running, whether a Snyk token is saved), the latest version, and the one thing left to do
                 ("Next:") or "Ready:". Never prints the token.
  --entry        For when your organisation blocks the extension: install the same release as a Claude
                 Desktop mcpServers entry instead. It needs uv: if uv is missing, the installer asks whether to
                 install it (see --install-uv). Installs the release in
                 ~/Library/Application Support/snyk-mcp/server, then adds a "snyk-mcp" entry to Claude
                 Desktop's claude_desktop_config.json (asks first; with no terminal, add --yes). It keeps a
                 backup of that file and everything else in it. Then quit and reopen Claude Desktop; the
                 installer waits until the entry is running. Running it again updates the release.
  --install-uv   With --entry: if uv is missing, install it without asking (the user's go-ahead, for agents and
                 scripts): with Homebrew if there is one (brew install uv), otherwise uv's own release from
                 GitHub, checked against a SHA-256 pinned in this installer, into ~/.local/bin. Shell profiles
                 aren't changed. Does nothing when uv is already installed.
  --set-token    Only add or replace your Snyk token: asks for it with hidden input, checks it with Snyk and
                 saves it to your Keychain. Create one at app.snyk.io > Account settings > Personal access
                 tokens (sign in with your company single sign-on; tokens last at most 90 days).
  --no-wait      Open Claude Desktop's install dialog and exit without waiting for you to click Install
                 (same as SNYK_INSTALL_WAIT_SECS=0); with --entry, exit without waiting for Claude Desktop
                 to start the entry. Check later with --status: exit 0 means the installer finished its
                 steps, not that Claude Desktop installed the extension.
  --uninstall    Remove the download folder (asks first; with no terminal, add --yes). The extension itself
                 is removed in Claude Desktop: Settings > Extensions. With --entry: remove the snyk-mcp
                 entry from claude_desktop_config.json (keeping a backup) and the installed release instead.
  --yes          Answer yes to removing a folder or the entry, and to adding or changing the entry in
                 claude_desktop_config.json. Installing uv is a separate yes: --install-uv.
  --help         Show this help.

Environment:
  SNYK_MCP_HOME
      Same as --dir (--dir wins).
  SNYK_INSTALL_TTY
      Where questions are read from; /dev/null means no terminal (every answer is no).
  SNYK_INSTALL_BASE
      Where the release files are downloaded from (default: the project site). For testing.
  SNYK_INSTALL_UV
      Where --entry looks for uv, colon-separated (default: uv on PATH, then /opt/homebrew/bin/uv,
      /usr/local/bin/uv, ~/.local/bin/uv).
  SNYK_MCP_DATA_DIR
      The server's data folder (default ~/Library/Application Support/snyk-mcp); --entry installs into its
      server folder.
EOF
}

# Physical path of $1 with symlinks resolved in the part that already exists, so the restricted-folder
# checks can't be dodged with symlinks, double slashes or a different spelling.
canonical_path() {
  local path="$1" rest="" dir
  while [[ ! -d "$path" ]]; do
    rest="/${path##*/}$rest"
    path="${path%/*}"
    [[ -n "$path" ]] || path="/"
  done
  dir="$(cd -P "$path" 2>/dev/null && pwd -P)" || return 1
  [[ "$dir" != "/" ]] || dir=""
  printf '%s%s\n' "$dir" "$rest"
}

lowercase() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Questions are read from the terminal, not stdin (stdin is the script itself under curl | bash).
can_answer() { [[ "$SNYK_INSTALL_TTY_PATH" != /dev/null ]] && { : <"$SNYK_INSTALL_TTY_PATH"; } 2>/dev/null; }

ask_yes_no() {
  local reply=""
  can_answer || return 1
  printf '%s [y/N] ' "$1" >"$SNYK_INSTALL_TTY_PATH"
  read -r reply <"$SNYK_INSTALL_TTY_PATH" || return 1
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

sha256_of() {
  # Hash from stdin: shasum escapes file names containing backslashes and prefixes the hash with "\".
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum <"$1" | awk '{ print $1 }'
  else
    shasum -a 256 <"$1" | awk '{ print $1 }'
  fi
}

# Succeeds when dotted version $1 >= $2 (numeric per part; missing parts count as 0).
version_ge() {
  awk -v a="$1" -v b="$2" 'BEGIN {
    n = split(a, x, "."); m = split(b, y, "."); if (m > n) n = m
    for (i = 1; i <= n; i++) { if (x[i] + 0 > y[i] + 0) exit 0; if (x[i] + 0 < y[i] + 0) exit 1 }
    exit 0
  }'
}

# Succeeds when release $1 is older than $2. X.Y.Z compares part by part; a pre-release (X.Y.Z-rc.N) is older than
# its X.Y.Z, and two pre-releases of one X.Y.Z compare as text.
version_older() {
  local a="${1%%-*}" b="${2%%-*}"
  [[ "$1" != "$2" ]] || return 1
  if [[ "$a" != "$b" ]]; then
    if version_ge "$a" "$b"; then return 1; fi
    return 0
  elif [[ "$1" == *-* && "$2" == *-* ]]; then
    [[ "$1" < "$2" ]]
  else
    [[ "$1" == *-* ]]
  fi
}

# Claude Desktop's version (CFBundleShortVersionString), or nothing if it can't be read.
claude_version() {
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$1/Contents/Info.plist" 2>/dev/null || true
}

# What Claude Desktop lists for this extension, read with JavaScript for Automation (no jq, node or python):
#   "<version> <enabled|disabled|blocked|unknown> <org-set|org-default|unknown> <writes-on|writes-off|unknown>", or
#   "none" when it isn't installed. blocked: the organisation hasn't approved the extension, so Claude Desktop keeps
#   it switched off (orgBlockedReason, "Extension is not approved for your organization", seen 2026-11-16; only its
#   presence is read). $1 = Claude Desktop's Application Support folder. Never prints the organisation.
claude_extension_state() {
  osascript -l JavaScript - "$1" <<'JXA' 2>/dev/null || echo none
ObjC.import("Foundation");
function readJson(path) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(
    $(path).stringByResolvingSymlinksInPath,
    $.NSUTF8StringEncoding,
    null,
  );
  if (text.isNil()) return null;
  try {
    return JSON.parse(text.js);
  } catch (e) {
    return null;
  }
}
function run(argv) {
  const all = (readJson(argv[0] + "/extensions-installations.json") || {}).extensions || {};
  const key = Object.keys(all).find((k) => /^[A-Za-z0-9._-]+\.snyk-mcp$/.test(k));
  if (!key || !all[key] || !/^[0-9A-Za-z.+-]{1,40}$/.test(String(all[key].version || ""))) return "none";
  const settings = readJson(argv[0] + "/Claude Extensions Settings/" + key + ".json");
  let enabled = "unknown";
  let org = "unknown";
  let writes = "unknown";
  if (settings) {
    if (settings.isEnabled === true) enabled = "enabled";
    if (settings.isEnabled === false) enabled = "disabled";
    const blocked = settings.orgBlockedReason;
    if (typeof blocked === "string" && blocked.trim()) enabled = "blocked";
    const config = settings.userConfig || {};
    const value = config.org;
    org = typeof value === "string" && value.trim() ? "org-set" : "org-default";
    const w = config.enable_write_tools;
    writes = w === true || w === "true" ? "writes-on" : "writes-off";
  }
  return String(all[key].version) + " " + enabled + " " + org + " " + writes;
}
JXA
}

# Is Claude Desktop open?
claude_running() { pgrep -x Claude >/dev/null 2>&1; }

# What Claude Desktop's own log for a server says about it, from the last start on:
#   "<none|starting|running|stopped|failed> <UTC time> <error text, for failed>". $1 = the log file.
# A reply logged after a shutdown (a late answer from a server being stopped) doesn't count as running. Reads from
# the last start in the whole log: Claude Desktop logs every message, so a busy server's start can be thousands of
# lines back.
server_state() {
  local from
  [[ -f "$1" && -r "$1" ]] || {
    echo none
    return 0
  }
  from="$(grep -n -F 'Initializing server...' "$1" 2>/dev/null | tail -n 1 | cut -d: -f1)"
  [[ -n "$from" ]] || {
    echo none
    return 0
  }
  tail -n "+$from" "$1" | awk '
    match($0, /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9:.]*Z /) {
      ts = substr($0, 1, RLENGTH - 2)
      if (index($0, "Initializing server...")) { state = "starting"; since = ts; err = ""; next }
      if (state == "") next
      if (index($0, "transport closed unexpectedly")) { state = "failed"; since = ts; next }
      if (index($0, "] [error] ")) {
        e = $0
        sub(/^.*\] \[error\] /, "", e)
        if (err == "") err = substr(e, 1, 140)
        if (index(e, "Server disconnected")) { state = "failed"; since = ts }
        next
      }
      if (state == "failed") next
      if (index($0, "Shutting down server") || index($0, "shutting down server")) { state = "stopped"; since = ts; next }
      if (state == "starting" && index($0, "Message from server:")) { state = "running"; since = ts }
    }
    END { if (state == "") print "none"; else print state, since, err }'
}

# A UTC time from the log ("2026-10-15T13:58:54.739") as local time: "14:58" today, "15 Oct 14:58" otherwise.
local_time() {
  local epoch
  epoch="$(date -j -u -f '%Y-%m-%dT%H:%M:%S' "${1%%.*}" '+%s' 2>/dev/null)" || {
    printf '%s UTC\n' "${1%%.*}"
    return 0
  }
  if [[ "$(date -r "$epoch" '+%Y-%m-%d')" == "$(date '+%Y-%m-%d')" ]]; then
    date -r "$epoch" '+%H:%M'
  else
    date -r "$epoch" '+%e %b %H:%M' | sed 's/^ //'
  fi
}

# A token is saved when the Keychain has the extension's item. Never reads the secret.
signin_saved() { security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$KEYCHAIN_TOKEN_ACCOUNT" >/dev/null 2>&1; }

# Snyk tokens are letters, digits and . _ ~ + / = - only; anything else can't be one (and can't break the
# command that saves it).
# (The length is checked apart: macOS's bash 3.2 refuses a regex repeat count above 255, and real tokens are longer.)
token_shape_ok() { [[ "$1" =~ ^[A-Za-z0-9._~+/=-]+$ ]] && [[ ${#1} -ge 20 && ${#1} -le 2048 ]]; }

# Which Snyk API host accepts the token: prints it and succeeds, or fails. The token reaches curl through a config
# on stdin, never on a command line (where other programs could read it).
find_snyk_host() {
  local token="$1" host code scheme="${SNYK_INSTALL_API_SCHEME:-https}"
  for host in ${SNYK_INSTALL_API_HOSTS:-api.snyk.io api.eu.snyk.io api.au.snyk.io api.us.snyk.io}; do
    code="$(printf 'header = "Authorization: token %s"\n' "$token" |
      curl -sS -m 20 -o /dev/null -w '%{http_code}' -K - "$scheme://$host/rest/self?version=2024-10-15" 2>/dev/null)" || code=000
    if [[ "$code" == 200 ]]; then
      printf '%s\n' "$host"
      return 0
    fi
  done
  return 1
}

# Saves a value to the Keychain through `security -i`, which reads its commands from stdin, so the value is never in
# the process list. Reads it back to be sure.
keychain_save() {
  local account="$1" value="$2" back
  printf 'add-generic-password -U -s %s -a %s -w "%s"\n' "$KEYCHAIN_SERVICE" "$account" "$value" | security -i >/dev/null 2>&1 || true
  back="$(security find-generic-password -s "$KEYCHAIN_SERVICE" -a "$account" -w 2>/dev/null || true)"
  [[ "$back" == "$value" ]]
}

# Asks for the token (hidden), checks it with Snyk and saves it. Returns 0 when saved. $1 = prompt intro.
# The answers come from one open descriptor (3), so each read takes the next line even from a plain file.
set_token() {
  local rc
  can_answer || return 2
  exec 3<"$SNYK_INSTALL_TTY_PATH"
  ask_and_save_token "$1"
  rc=$?
  exec 3<&-
  return $rc
}

ask_and_save_token() {
  local token host tries=0
  {
    echo ""
    echo "$1"
    echo "  1. Open https://app.snyk.io/account and sign in with your company single sign-on (Okta)."
    echo "  2. Account settings > Personal access tokens > Generate new token (pick an expiry, 90 days at most)."
    echo "  3. Click Copy and paste it below. It is shown only once; you won't see what you paste."
  } >&2
  while [[ $tries -lt 3 ]]; do
    tries=$((tries + 1))
    printf 'Snyk token (hidden, empty to skip): ' >&2
    token=""
    read -rs token <&3 || return 1
    printf '\n' >&2
    [[ -n "$token" ]] || return 1
    token="${token//[[:space:]]/}"
    if ! token_shape_ok "$token"; then
      print_warning "That doesn't look like a Snyk token. Copy the whole token and try again."
      continue
    fi
    if ! host="$(find_snyk_host "$token")"; then
      print_warning "Snyk didn't accept that token (expired, revoked, or copied incompletely). Try again."
      continue
    fi
    if keychain_save "$KEYCHAIN_TOKEN_ACCOUNT" "$token" && keychain_save "$KEYCHAIN_HOST_ACCOUNT" "$host"; then
      print_success "Token checked with Snyk ($host) and saved in your Keychain"
      return 0
    fi
    print_error "The macOS Keychain wouldn't keep it (is your login Keychain unlocked?)"
    return 1
  done
  return 1
}

# The Snyk token, for an install of either kind: asked for in a terminal (hidden) when none is saved, so a typo can
# be corrected here rather than in the chat. With no terminal it never asks: Claude's token card does. $1 = site
# base, $2 = download folder.
token_step() {
  if signin_saved; then
    print_success "A Snyk token is already saved in your Keychain"
  elif can_answer; then
    set_token "Your Snyk token (kept in your macOS Keychain only):" || print_warning "No token saved. Claude will show a card in the chat where you can add it, or run: $(set_token_cmd "$1" "$2")"
  else
    print_warning "No Snyk token is saved. Claude will show a card in the chat where the owner can add it, or run: $(set_token_cmd "$1" "$2")"
  fi
}

# The extension state as a sentence part, e.g. "0.10.0 (enabled, organisation set)".
describe_extension() {
  local version="$1" enabled="$2" org="$3" notes=()
  case "$enabled" in
    unknown) ;;
    blocked) notes+=("blocked by your organisation") ;;
    *) notes+=("$enabled") ;;
  esac
  # The organisation is optional: say so only when one is set.
  [[ "$org" != org-set ]] || notes+=("organisation set")
  if [[ ${#notes[@]} -gt 0 ]]; then
    local joined
    joined="$(printf '%s, ' "${notes[@]}")"
    printf '%s (%s)\n' "$version" "${joined%, }"
  else
    printf '%s\n' "$version"
  fi
}

switch_on_hint() {
  echo "  In Claude Desktop open Settings > Extensions > $APP_TITLE and switch it on (click once, then wait a"
  echo "  few seconds)."
}

# The organisation hasn't approved the extension: the same release runs as an mcpServers entry. $1 = that command.
blocked_hint() {
  echo "  Your organisation hasn't approved Claude Desktop extensions like this one, so Claude Desktop keeps it"
  echo "  switched off. Install the same release as a Claude Desktop mcpServers entry instead:"
  echo "    $1"
  if [[ -z "$(find_uv)" ]]; then
    echo "  The entry needs uv, which isn't installed: the installer asks whether to install it (with no terminal,"
    echo "  add --install-uv once the user agrees)."
  fi
}

# This installer's own command line, to run it again with a go-ahead the person hasn't given yet: the same site, the
# variables they set that change what it does (no terminal, folders, site), their options, and $1 (e.g. --yes) unless
# they gave it. Every value is shell-quoted, so the line can be pasted as it is. main fills SNYK_AGAIN.
SNYK_AGAIN=""
SNYK_ARGS=()
again_with() {
  local cmd="$SNYK_AGAIN" a have=false
  for a in "${SNYK_ARGS[@]+"${SNYK_ARGS[@]}"}"; do
    [[ "$a" != "$1" ]] || have=true
  done
  [[ "$have" == true ]] || cmd+=" $1"
  printf '%s\n' "$cmd"
}

# The command that adds a token without reinstalling, for messages. $1 = site base, $2 = download folder.
set_token_cmd() {
  local q_base
  printf -v q_base '%q' "$1"
  printf 'curl -fsSL %s/install.sh | bash -s -- --set-token' "$q_base"
}

# ---- The mcpServers entry (--entry) ----

# The uv --entry uses, or nothing: the places the entry's command looks too (snyk_mcp/managed.py). Always succeeds.
find_uv() {
  local candidates=() candidate
  if [[ -n "${SNYK_INSTALL_UV+set}" ]]; then
    IFS=: read -r -a candidates <<<"$SNYK_INSTALL_UV"
  else
    candidates=("$(command -v uv 2>/dev/null || true)" /opt/homebrew/bin/uv /usr/local/bin/uv "${HOME%/}/.local/bin/uv")
  fi
  [[ ${#candidates[@]} -gt 0 ]] || return 0
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -f "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 0
}

# Homebrew's brew, or nothing. Always succeeds.
find_brew() {
  if [[ -n "${SNYK_INSTALL_BREW+set}" ]]; then
    if [[ -n "$SNYK_INSTALL_BREW" && -x "$SNYK_INSTALL_BREW" ]]; then printf '%s\n' "$SNYK_INSTALL_BREW"; fi
    return 0
  fi
  local candidate
  for candidate in "$(command -v brew 2>/dev/null || true)" /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 0
}

# How install_uv would install uv, in words that follow "install uv" in the question and the refusal.
uv_install_how() {
  if [[ -n "$(find_brew)" ]]; then
    echo "with Homebrew (brew install uv)"
  else
    echo "from its GitHub release (version $UV_VERSION, checked against its SHA-256) into ~/.local/bin"
  fi
}

# Installs uv (only after the owner agreed, or --install-uv): with Homebrew if there is one, else uv's own release
# from GitHub, checked against the pinned SHA-256 before anything is unpacked, into ~/.local/bin. Never changes a
# shell profile and never replaces a uv that is there. Says why on failure.
install_uv() {
  local brew
  brew="$(find_brew)"
  if [[ -n "$brew" ]]; then
    print_step "Installing uv with Homebrew (brew install uv)..."
    "$brew" install uv || {
      print_error "brew install uv failed (its output is above)"
      return 1
    }
    return 0
  fi
  local arch expected name url tmp actual bin="${HOME%/}/.local/bin"
  case "$(uname -m)" in
    arm64 | aarch64) arch=aarch64 expected="$UV_SHA256_AARCH64" ;;
    x86_64) arch=x86_64 expected="$UV_SHA256_X86_64" ;;
    *)
      print_error "uv has no release for this Mac's processor ($(uname -m))"
      return 1
      ;;
  esac
  [[ -z "${SNYK_INSTALL_UV_SHA256:-}" ]] || expected="$SNYK_INSTALL_UV_SHA256"
  name="uv-$arch-apple-darwin"
  url="${SNYK_INSTALL_UV_BASE:-https://github.com/astral-sh/uv/releases/download/$UV_VERSION}"
  url="${url%/}/$name.tar.gz"
  print_step "Installing uv $UV_VERSION from its GitHub release into ~/.local/bin..."
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/snyk-uv.XXXXXX")" || return 1
  if ! curl -fsSL "$url" -o "$tmp/uv.tar.gz"; then
    rm -rf "$tmp"
    print_error "Download failed: $url"
    return 1
  fi
  actual="$(sha256_of "$tmp/uv.tar.gz")"
  if [[ "$actual" != "$expected" ]]; then
    rm -rf "$tmp"
    print_error "uv's checksum doesn't match — uv wasn't installed"
    print_error "Expected: $expected"
    print_error "Got:      $actual"
    return 1
  fi
  if ! tar -xzf "$tmp/uv.tar.gz" -C "$tmp" "$name/uv" 2>/dev/null || [[ ! -f "$tmp/$name/uv" ]]; then
    rm -rf "$tmp"
    print_error "uv's release didn't hold $name/uv"
    return 1
  fi
  if [[ -e "$bin/uv" ]]; then
    rm -rf "$tmp"
    print_error "$bin/uv is there already but can't be run; leaving it alone"
    return 1
  fi
  if ! { mkdir -p "$bin" && install -m 755 "$tmp/$name/uv" "$bin/.uv.$$" && mv -f "$bin/.uv.$$" "$bin/uv"; }; then
    rm -rf "$tmp" "$bin/.uv.$$"
    print_error "Couldn't put uv in $bin"
    return 1
  fi
  rm -rf "$tmp"
  print_success "Installed uv $UV_VERSION in $bin (your shell profiles weren't changed; the entry finds it there)"
}

# The server's data folder, as the server finds it on macOS (snyk_mcp/managed.py: $SNYK_MCP_DATA_DIR, else
# ~/Library/Application Support/snyk-mcp), spelt as Python's Path spells it (no "//", "/./" or trailing "/"), so the
# entry's command compares equal to the one the release writes.
entry_data_dir() {
  # The same spelling as snyk_mcp/config.py spell_dir (tests/test_install_sh.py compares the two): surrounding
  # whitespace trimmed, a leading ~ or ~/ made $HOME, every run of slashes made one (a leading "//" too), "."
  # segments and a trailing slash dropped.
  local LC_ALL=C d="${SNYK_MCP_DATA_DIR:-}" parts=() part out=""
  d="${d#"${d%%[![:space:]]*}"}"
  d="${d%"${d##*[![:space:]]}"}"
  [[ -n "$d" ]] || d="${HOME%/}/Library/Application Support/snyk-mcp"
  if [[ "$d" == \~ || "$d" == \~/* ]]; then d="$HOME${d:1}"; fi
  IFS=/ read -r -a parts <<<"$d"
  for part in "${parts[@]+"${parts[@]}"}"; do
    [[ -z "$part" || "$part" == . ]] || out="$out/$part"
  done
  if [[ "$d" == /* ]]; then
    d="${out:-/}"
  else
    d="${out#/}"
    [[ -n "$d" ]] || d=.
  fi
  printf '%s\n' "$d"
}

# Whether a file can be read: "ok", "missing" (provably not there) or "unreadable" (there, or perhaps there, behind a
# folder or link that can't be read). Follows links (at most 20). Always succeeds. $1 = the path, $2 = links followed.
probe() {
  local p="$1" n="${2:-0}" t parent up
  if [[ -e "$p" ]]; then
    if [[ -d "$p" ]]; then
      if [[ -r "$p" && -x "$p" ]]; then echo ok; else echo unreadable; fi
    elif [[ -r "$p" ]]; then
      echo ok
    else
      echo unreadable
    fi
    return 0
  fi
  if [[ -L "$p" ]]; then
    # A link to nothing is "missing"; one that can't be read or followed (a loop) is "unreadable".
    if [[ "$n" -ge 20 ]] || ! t="$(readlink "$p" 2>/dev/null)"; then
      echo unreadable
      return 0
    fi
    [[ "$t" == /* ]] || t="${p%/*}/$t"
    probe "$t" $((n + 1))
    return 0
  fi
  parent="${p%/*}"
  [[ -n "$parent" ]] || parent=/
  if [[ "$parent" == "$p" ]]; then
    echo missing
    return 0
  fi
  if [[ -d "$parent" && -x "$parent" ]]; then
    echo missing
    return 0
  fi
  up="$(probe "$parent" "$n")"
  if [[ "$up" == missing || ("$up" == ok && ! -d "$parent") ]]; then echo missing; else echo unreadable; fi
}

# Claude Desktop's config file followed through symbolic links (a dotfile manager's, say), so it is read and changed
# where it really is and the link stays. $1 = the path Claude Desktop reads. Prints the real file's path and succeeds;
# or prints the link where it stopped and fails, for a link it won't follow: a loop or more than 20 links in a row
# (changing it would turn a link into a file), or a link to nothing (changing it would create a file and folders
# where the link points).
config_target() {
  local p="$1" t n=0
  while [[ -L "$p" ]]; do
    if [[ "$n" -ge 20 ]] || ! t="$(readlink "$p")"; then
      printf '%s\n' "$p"
      return 1
    fi
    [[ "$t" == /* ]] || t="$(dirname "$p")/$t"
    p="$t"
    n=$((n + 1))
  done
  printf '%s\n' "$p"
  if [[ "$n" -gt 0 && ! -e "$p" ]]; then return 1; fi
  return 0
}

# The version of the release an entry runs ($1 = <server folder>/current/manifest.json), or "none".
release_version() {
  osascript -l JavaScript - "$1" <<'JXA' 2>/dev/null || echo none
ObjC.import("Foundation");
function run(argv) {
  const text = $.NSString.stringWithContentsOfFileEncodingError(
    $(argv[0]).stringByResolvingSymlinksInPath,
    $.NSUTF8StringEncoding,
    null,
  );
  if (text.isNil()) return "none";
  try {
    const version = String(JSON.parse(text.js).version || "");
    return /^[0-9]+\.[0-9]+\.[0-9]+$/.test(version) ? version : "none";
  } catch (e) {
    return "none";
  }
}
JXA
}

# Reads or changes the entry in Claude Desktop's config file, with JavaScript for Automation (no jq, node or python).
#   entry_config state  <config> <launcher>
#     -> "missing" (no file), "unreadable" (there but can't be read), "invalid" (not a JSON object), "none" (no
#        entry), "ours" (it runs <launcher>) or "other" (it runs something else); "error" if osascript fails
#   entry_config add    <config> <launcher> <env JSON> <out>
#   entry_config remove <config> <launcher> <out>
#     -> "changed" (the whole new file is written to <out>), "unchanged", "invalid", "unreadable", or for remove
#        "other" (an entry that runs something else is left alone). add keeps every other key; an entry that runs
#        something else is pointed at <launcher> and keeps its env (the owner's settings); a new one gets <env JSON>.
# JSON.parse and JSON.stringify keep every key and its order, except that keys made only of digits move first, and
# numbers past 2^53 lose precision (1e400 becomes null). Claude Desktop's config has neither (INSTALL.md says so).
entry_config() {
  osascript -l JavaScript - "$ENTRY_NAME" "$@" <<'JXA' 2>/dev/null || echo error
ObjC.import("Foundation");
const isObject = (v) => v !== null && typeof v === "object" && !Array.isArray(v);
function run(argv) {
  const [name, action, path, launcher] = argv;
  let config = {};
  if ($.NSFileManager.defaultManager.fileExistsAtPath(path)) {
    const text = $.NSString.stringWithContentsOfFileEncodingError(path, $.NSUTF8StringEncoding, null);
    if (text.isNil()) return "unreadable";
    try {
      config = JSON.parse(text.js);
    } catch (e) {
      return "invalid";
    }
    if (!isObject(config)) return "invalid";
  } else if (action === "state") {
    return "missing";
  }
  if (config.mcpServers !== undefined && !isObject(config.mcpServers)) return "invalid";
  const servers = config.mcpServers || {};
  const entry = servers[name];
  const ours = isObject(entry) && entry.command === launcher;
  if (action === "state") return entry === undefined ? "none" : ours ? "ours" : "other";
  let out;
  if (action === "remove") {
    if (entry === undefined) return "unchanged";
    if (!ours) return "other";
    delete servers[name];
    out = argv[4];
  } else if (action === "add") {
    if (ours) return "unchanged";
    if (isObject(entry)) {
      entry.command = launcher;
      entry.args = [];
    } else {
      servers[name] = { command: launcher, args: [], env: JSON.parse(argv[4]) };
    }
    config.mcpServers = servers;
    out = argv[5];
  } else {
    return "error";
  }
  const ok = $(JSON.stringify(config, null, 2) + "\n").writeToFileAtomicallyEncodingError(
    out,
    false,
    $.NSUTF8StringEncoding,
    null,
  );
  return ok ? "changed" : "error";
}
JXA
}

# The entry's state in Claude Desktop's config (entry_config state), with "unreadable" for a file, or a folder on its
# way, that is there but can't be read. $1 = the real file (config_target), $2 = the launcher.
config_state() {
  case "$(probe "$1")" in
    missing) echo missing ;;
    unreadable) echo unreadable ;;
    *) entry_config state "$1" "$2" ;;
  esac
}

# Why Claude Desktop's config can't be used, for messages. $1 = its state (or "link", from config_target).
config_problem() {
  case "$1" in
    invalid) echo "Claude Desktop's config can't be read as JSON" ;;
    link) echo "Claude Desktop's config is a link that can't be followed (a loop, more than 20 links in a row, or a link to nothing)" ;;
    *) echo "Claude Desktop's config can't be read (check its permissions, and its folder's)" ;;
  esac
}

# A string as a JSON string literal.
json_string() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '"%s"' "$s"
}

# The PATH a new entry gets: uv's folder ($1) first, then the folders Claude Desktop doesn't add itself.
entry_path() {
  local d out="" seen=":"
  for d in "$1" /opt/homebrew/bin /usr/local/bin /usr/bin /bin /usr/sbin /sbin; do
    [[ -n "$d" && "$seen" != *":$d:"* ]] || continue
    out="${out:+$out:}$d"
    seen="$seen$d:"
  done
  printf '%s\n' "$out"
}

# A new entry's env, as JSON: MCP_RUN_MODE, the PATH (uv's folder, $1, first) and, when the owner chose another data
# folder, SNYK_MCP_DATA_DIR spelt as the server spells it (the launcher doesn't pass it on, and the server must use
# the folder the release is in).
entry_env_json() {
  local json chosen="${SNYK_MCP_DATA_DIR:-}"
  json="{ \"MCP_RUN_MODE\": \"config\", \"PATH\": $(json_string "$(entry_path "$1")")"
  if [[ -n "${chosen//[[:space:]]/}" ]]; then
    json+=", \"SNYK_MCP_DATA_DIR\": $(json_string "$(entry_data_dir)")"
  fi
  printf '%s }\n' "$json"
}

# Changes Claude Desktop's config with entry_config add or remove ($1), safely: the new file is written beside the
# real one ($2, from config_target), so the rename is atomic, checked, given the real file's permissions (0600, as
# Claude Desktop's own, for a new file) and renamed over it after a backup to <config>.bak-<date and time>-<random>
# (a name mktemp reserves, so runs at the same moment never share one). Prints the backup's path (nothing when there
# was no file). $3 = the launcher, $4 = a new entry's env JSON (add only). Says why on failure.
write_config() {
  local action="$1" cfg="$2" launcher="$3" env_json="${4:-}" dir new result want backup="" mode=600
  dir="$(dirname "$cfg")"
  if ! mkdir -p "$dir" || ! new="$(mktemp "$dir/.claude_desktop_config.json.snyk-mcp.XXXXXX")"; then
    print_error "Couldn't write beside $cfg; it wasn't changed"
    return 1
  fi
  if [[ "$action" == add ]]; then
    result="$(entry_config add "$cfg" "$launcher" "$env_json" "$new")"
    want=ours
  else
    result="$(entry_config remove "$cfg" "$launcher" "$new")"
    want=none
  fi
  if [[ "$result" != changed || "$(entry_config state "$new" "$launcher")" != "$want" ]]; then
    rm -f "$new"
    print_error "Couldn't prepare the new config ($result); $cfg wasn't changed"
    return 1
  fi
  if [[ -f "$cfg" ]]; then
    if ! mode="$(stat -L -f '%Lp' "$cfg")" || ! backup="$(mktemp "$cfg.bak-$(date '+%Y-%m-%dT%H%M%S')-XXXXXX")" ||
      ! cp -p "$cfg" "$backup"; then
      rm -f "$new"
      print_error "Couldn't back up $cfg; it wasn't changed"
      return 1
    fi
  fi
  if ! chmod "$mode" "$new" || ! mv -f "$new" "$cfg"; then
    rm -f "$new"
    print_error "Couldn't write $cfg${backup:+ (its backup: $backup)}"
    return 1
  fi
  printf '%s\n' "$backup"
}

# The entry as JSON, for adding it by hand: the same command and env the installer would write. $1 = the launcher,
# $2 = Claude Desktop's config file, $3 = the env JSON.
print_entry_by_hand() {
  echo "To add it yourself: back up $2, put this inside its \"mcpServers\" object, then quit and reopen"
  echo "Claude Desktop:"
  echo ""
  echo "  $(json_string "$ENTRY_NAME"): {"
  echo "    \"command\": $(json_string "$1"),"
  echo "    \"args\": [],"
  echo "    \"env\": $3"
  echo "  }"
  echo ""
}

# When a file or link last changed, as a UTC time in Claude Desktop's log format ("2026-11-16T07:55:49"), or nothing.
changed_at() {
  local epoch
  epoch="$(stat -f '%m' "$1" 2>/dev/null)" || return 0
  date -u -r "$epoch" '+%Y-%m-%dT%H:%M:%S'
}

# The server state as words for --status. $1 = state, $2 = UTC time, $3 = error text.
describe_server() {
  case "$1" in
    running) echo "running since $(local_time "$2")" ;;
    starting) echo "starting since $(local_time "$2") (the first start downloads Python and the dependencies)" ;;
    stopped) echo "stopped at $(local_time "$2")" ;;
    failed) echo "failed at $(local_time "$2")${3:+: $3}" ;;
    *) echo "hasn't started yet" ;;
  esac
}

# The one thing left to do, or "" when the extension (or the entry) is ready. $1..$3 = extension state, $4 = its
# server state, $5 = Claude Desktop open (true/false), $6 = the --entry command; for the entry, $7 = its release
# ("none" if not installed), $8 = its config state (entry_config state), $9 = its server state, $10 = true when its
# server last started before the release in use was installed; $11 = true when uv is installed; $12 = the entry's
# server folder, $13 = Claude Desktop's config file. Something that can't be read is never called missing: the
# owner is told to make it readable, not to install or add what may be there already.
next_step() {
  local ext_version="$1" enabled="$2" _org="$3" server="$4" open="$5" entry_cmd="$6"
  local release="${7:-none}" cfg_state="${8:-none}" entry_server="${9:-none}" stale="${10:-false}" has_uv="${11:-true}"
  local server_dir="${12:-}" cfg="${13:-}"
  if [[ "$release" != none || "$cfg_state" == ours || "$cfg_state" == other ]]; then
    if [[ "$release" == unreadable ]]; then
      echo "the release in $server_dir can't be read: check that folder's permissions (ls -ld), then check again."
    elif [[ "$cfg_state" == unreadable || "$cfg_state" == error || "$cfg_state" == link ]]; then
      echo "$(config_problem "$cfg_state") ($cfg): fix it, then check again."
    elif [[ "$has_uv" != true ]]; then
      echo "install uv, which the $ENTRY_NAME entry runs with (ask first): $entry_cmd --install-uv"
    elif [[ "$release" == none ]]; then
      echo "install the release for the $ENTRY_NAME entry: $entry_cmd"
    elif [[ "$cfg_state" == invalid ]]; then
      echo "Claude Desktop's claude_desktop_config.json can't be read as JSON: fix it, then run $entry_cmd"
    elif [[ "$cfg_state" != ours ]]; then
      echo "add the $ENTRY_NAME entry to Claude Desktop's config: $entry_cmd"
    elif [[ "$ext_version" != none && "$enabled" != disabled && "$enabled" != blocked ]]; then
      echo "switch the extension off (Settings > Extensions > $APP_TITLE): with the entry on too, Claude sees every tool twice."
    elif [[ "$open" != true ]]; then
      echo "open Claude Desktop."
    elif [[ "$entry_server" == failed ]]; then
      echo "quit and reopen Claude Desktop; if it still fails, see ~/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log."
    elif [[ "$entry_server" == none || "$entry_server" == stopped ]]; then
      echo "quit Claude Desktop (⌘Q) and open it again, so it starts the $ENTRY_NAME entry."
    elif [[ "$entry_server" == running && "$stale" == true ]]; then
      echo "quit Claude Desktop (⌘Q) and open it again, so it starts release $release."
    elif [[ "$entry_server" != running ]]; then
      echo "wait a minute and check again: Claude Desktop is starting the $ENTRY_NAME entry."
    fi
    return 0
  fi
  if [[ "$ext_version" == unreadable ]]; then
    echo "Claude Desktop's list of extensions can't be read: check the permissions of ~/Library/Application Support/Claude, then check again."
  elif [[ "$ext_version" == none ]]; then
    echo "run the install command, then click Install in Claude Desktop."
  elif [[ "$enabled" == blocked && "$has_uv" == true ]]; then
    echo "your organisation blocks the extension: install it as an mcpServers entry instead: $entry_cmd"
  elif [[ "$enabled" == blocked ]]; then
    echo "your organisation blocks the extension: install it as an mcpServers entry instead. It needs uv, which isn't installed: ask first, then $entry_cmd --install-uv"
  elif [[ "$enabled" == disabled ]]; then
    echo "switch the extension on in Claude Desktop: Settings > Extensions > $APP_TITLE."
  elif [[ "$open" != true ]]; then
    echo "open Claude Desktop."
  elif [[ "$server" == failed ]]; then
    echo "run the install command again; if it still fails, see ~/Library/Logs/Claude/mcp-server-$APP_TITLE.log."
  elif [[ "$server" != running ]]; then
    echo "wait a minute and check again: Claude Desktop is starting the extension."
  fi
}

print_status() {
  local dir="$1" base="$2" claude_app="$3" claude_support="$4" log_file="$5" entry_cmd="$6"
  local downloaded="" latest app_version state ext_version enabled org writes srv since err open=false next
  # Whatever it can't read, it says so on that line and carries on (it never calls it missing).
  case "$(probe "$dir/latest.version")" in
    ok) downloaded="$(tr -d '[:space:]' 2>/dev/null <"$dir/latest.version" || true)" ;;
    unreadable) downloaded="can't be read ($dir/latest.version)" ;;
  esac
  latest="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
  [[ -n "$latest" ]] || latest="unknown (couldn't reach $base)"
  if [[ "$(probe "$claude_support/extensions-installations.json")" == unreadable ]]; then
    state="unreadable unknown unknown unknown"
  else
    state="$(claude_extension_state "$claude_support")"
  fi
  read -r ext_version enabled org writes <<<"$state"
  read -r srv since err <<<"$(server_state "$log_file")"
  claude_running && open=true
  # The mcpServers entry (--entry): its installed release, its line in Claude Desktop's config, its server.
  local server_dir release cfg cfg_state e_srv e_since e_err switched stale=false entry_used=false
  server_dir="$(entry_data_dir)/server"
  case "$(probe "$server_dir/current/manifest.json")" in
    ok) release="$(release_version "$server_dir/current/manifest.json")" ;;
    unreadable) release=unreadable ;;
    *) release=none ;;
  esac
  if cfg="$(config_target "$claude_support/claude_desktop_config.json")"; then
    cfg_state="$(config_state "$cfg" "$server_dir/$LAUNCHER_NAME")"
  else
    cfg_state="link"
  fi
  read -r e_srv e_since e_err <<<"$(server_state "${HOME%/}/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log")"
  switched="$(changed_at "$server_dir/current")"
  if [[ "$e_srv" == running && -n "$switched" && "$e_since" < "$switched" ]]; then stale=true; fi
  if [[ "$release" != none || "$cfg_state" == ours || "$cfg_state" == other ]]; then entry_used=true; fi
  local uv_path has_uv=false
  uv_path="$(find_uv)"
  [[ -z "$uv_path" ]] || has_uv=true
  echo "$APP_TITLE"
  echo "  Download folder: $dir$([[ -d "$dir" ]] || echo " (missing)")"
  echo "  Downloaded:      ${downloaded:-nothing yet}"
  echo "  Latest:          $latest"
  if [[ -d "$claude_app" ]]; then
    app_version="$(claude_version "$claude_app")"
    echo "  Claude Desktop:  ${app_version:-version unknown} ($claude_app)$([[ "$open" == true ]] || echo ", not open")"
  else
    echo "  Claude Desktop:  not found at $claude_app"
  fi
  if [[ "$has_uv" == true ]]; then
    echo "  uv:              $uv_path"
  else
    echo "  uv:              not installed (only the mcpServers entry needs it; --entry offers to install it)"
  fi
  if [[ "$ext_version" == unreadable ]]; then
    echo "  Extension:       can't be read ($claude_support/extensions-installations.json)"
  elif [[ "$ext_version" == none ]]; then
    echo "  Extension:       not installed in Claude Desktop"
  else
    echo "  Extension:       $(describe_extension "$ext_version" "$enabled" "$org")"
    # Switched off by the organisation: its settings don't apply and its server never runs.
    if [[ "$enabled" != blocked ]]; then
      case "$writes" in
        writes-on) echo "  Write tools:     on (Claude can import repos, ignore issues and change projects in Snyk)" ;;
        writes-off) echo "  Write tools:     off" ;;
      esac
    fi
    if [[ "$enabled" == blocked ]]; then
      :
    elif [[ "$open" == true ]]; then
      echo "  Server:          $(describe_server "$srv" "$since" "$err")"
    else
      echo "  Server:          not running (Claude Desktop isn't open)"
    fi
  fi
  if [[ "$entry_used" == true ]]; then
    local where
    case "$cfg_state" in
      ours) where="in Claude Desktop's config as $ENTRY_NAME" ;;
      other) where="Claude Desktop's $ENTRY_NAME entry runs something else" ;;
      invalid) where="Claude Desktop's config can't be read as JSON" ;;
      unreadable | error) where="Claude Desktop's config can't be read ($cfg)" ;;
      link) where="Claude Desktop's config is a link that can't be followed ($cfg)" ;;
      *) where="not in Claude Desktop's config" ;;
    esac
    if [[ "$release" == none ]]; then
      echo "  Entry:           no release installed in $server_dir; $where"
    elif [[ "$release" == unreadable ]]; then
      echo "  Entry:           the release in $server_dir can't be read; $where"
    else
      echo "  Entry:           release $release, $where"
    fi
    if [[ "$open" == true ]]; then
      echo "  Entry server:    $(describe_server "$e_srv" "$e_since" "$e_err")"
    else
      echo "  Entry server:    not running (Claude Desktop isn't open)"
    fi
  fi
  if signin_saved; then
    echo "  Snyk token:      saved in your Keychain"
  else
    echo "  Snyk token:      none saved (run: $(set_token_cmd "$base" "$dir"), or Claude shows a card the first time you ask)"
  fi
  next="$(next_step "$ext_version" "$enabled" "$org" "$srv" "$open" "$entry_cmd" \
    "$release" "$cfg_state" "$e_srv" "$stale" "$has_uv" "$server_dir" "$cfg")"
  if [[ -n "$next" ]]; then
    echo "  Next:            $next"
  else
    echo "  Ready:           yes. Start a new chat in Claude Desktop and ask it about your Snyk projects."
  fi
  if [[ "$latest" != unknown* ]]; then
    if [[ "$entry_used" == true && "$latest" == *-* ]]; then
      echo "  The latest here is a pre-release: the mcpServers entry installs only stable releases."
    elif [[ "$release" == unreadable ]]; then
      :
    elif [[ "$entry_used" == true ]]; then
      if [[ "$release" == none ]] || version_older "$release" "$latest"; then
        echo "  Update available: click Update now on the update card in Claude, or run the --entry command again."
      else
        echo "  Up to date."
      fi
    elif [[ "$ext_version" == unreadable ]]; then
      :
    elif [[ "$ext_version" == none ]] || version_older "$ext_version" "$latest"; then
      echo "  Update available: run the install command again."
    else
      echo "  Up to date."
    fi
  fi
}

# --entry: installs the verified release ($dir/latest.mcpb) with that release's own `snyk-mcp install-release`,
# adds the snyk-mcp entry to Claude Desktop's config, and waits until Claude Desktop runs it. main has already
# checked the config and asked the owner: $6 = true when the config may be changed.
install_entry() {
  local dir="$1" version="$2" uv="$3" claude_app="$4" claude_support="$5" consent="$6" wait_secs="$7"
  local status_cmd="$8"
  local cfg
  cfg="$(config_target "$claude_support/claude_desktop_config.json")" || die "$(config_problem link): $cfg. Nothing in it was changed"
  local entry_log="${HOME%/}/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log"
  local server_dir before_release release launcher out
  server_dir="$(entry_data_dir)/server"
  before_release="$(release_version "$server_dir/current/manifest.json")"

  if [[ -n "$version" && "$before_release" == "$version" && -x "$server_dir/$LAUNCHER_NAME" ]]; then
    launcher="$server_dir/$LAUNCHER_NAME"
    print_success "Release $version is already installed in $server_dir"
  else
    # Never an "update" to an earlier version: say so (as the extension route does).
    if [[ -n "$version" && "$before_release" != none ]] && version_older "$version" "$before_release"; then
      print_warning "Release $before_release is installed, which is newer than $version, the site's latest: this replaces it with an earlier version."
    fi
    print_step "Installing the release for the $ENTRY_NAME entry (uv sets up Python and the dependencies: about a minute the first time)..."
    local stage="$SNYK_TEMP_DIR/release"
    mkdir -p "$stage"
    unzip -q -o "$dir/latest.mcpb" -d "$stage" >/dev/null 2>&1 || die "Couldn't unpack $dir/latest.mcpb"
    [[ -f "$stage/pyproject.toml" && -f "$stage/uv.lock" ]] || die "$dir/latest.mcpb isn't a release bundle"
    # The release installs itself (snyk_mcp/managed.py): it checks the bundle again, unpacks it beside the version in
    # use, syncs its locked dependencies and switches to it. Claude Desktop's config isn't touched yet.
    if ! out="$(cd "$stage" && env -u VIRTUAL_ENV -u UV_PROJECT_ENVIRONMENT "$uv" run --frozen --quiet \
      --project "$stage" snyk-mcp install-release --bundle "$dir/latest.mcpb" 2>&1)"; then
      print_error "Installing the release failed, so Claude Desktop's config wasn't changed:"
      printf '%s\n' "$out" | tail -n 15 >&2
      exit 1
    fi
    launcher="$(printf '%s\n' "$out" | sed -n "s/^$ENTRY_COMMAND_LABEL //p" | tail -n 1)"
    [[ -n "$launcher" && -x "$launcher" ]] || die "The release installed, but didn't say where its command is"
    server_dir="${launcher%/*}"
  fi
  release="$(release_version "$server_dir/current/manifest.json")"
  if [[ "$before_release" != none && "$release" != none ]] && version_older "$release" "$before_release"; then
    print_success "Installed release $release, an earlier version than the $before_release it replaces, in $server_dir"
  elif [[ "$before_release" != none && "$before_release" != "$release" ]]; then
    print_success "Installed release $release (was $before_release) in $server_dir"
  elif [[ "$before_release" == none ]]; then
    print_success "Installed release $release in $server_dir"
  fi

  # Claude Desktop's config: add the entry, or point an existing one at this release, if the owner agreed.
  local cfg_state changed=false env_json
  env_json="$(entry_env_json "${uv%/*}")"
  cfg_state="$(config_state "$cfg" "$launcher")"
  case "$cfg_state" in
    ours)
      print_success "Claude Desktop's config already has the $ENTRY_NAME entry"
      ;;
    none | missing | other)
      if [[ "$consent" != true ]]; then
        print_warning "Claude Desktop's config wasn't changed, as you chose."
        print_entry_by_hand "$launcher" "$cfg" "$env_json"
        return 0
      fi
      local backup
      backup="$(write_config add "$cfg" "$launcher" "$env_json")" || exit 1
      changed=true
      if [[ "$cfg_state" == other ]]; then
        print_success "Pointed Claude Desktop's $ENTRY_NAME entry at release $release${backup:+ (backup: $backup)}"
      else
        print_success "Added the $ENTRY_NAME entry to Claude Desktop's config${backup:+ (backup: $backup)}"
      fi
      ;;
    *)
      print_error "$(config_problem "$cfg_state"), so it was left alone: $cfg"
      print_entry_by_hand "$launcher" "$cfg" "$env_json" >&2
      exit 1
      ;;
  esac

  local ext_version enabled _org _writes
  read -r ext_version enabled _org _writes <<<"$(claude_extension_state "$claude_support")"
  if [[ "$ext_version" != none && "$enabled" != disabled && "$enabled" != blocked ]]; then
    print_warning "The $APP_TITLE extension is switched on too, so Claude would see every tool twice."
    echo "  Switch it off in Claude Desktop: Settings > Extensions > $APP_TITLE."
  fi

  # Claude Desktop reads its config when it starts: wait for a start of the entry from now on (or, when nothing
  # changed, one that runs this release already).
  local start_ts already=false srv since err switched
  start_ts="$(date -u '+%Y-%m-%dT%H:%M:%S')"
  read -r srv since err <<<"$(server_state "$entry_log")"
  switched="$(changed_at "$server_dir/current")"
  if [[ "$changed" != true && "$srv" == running && -n "$switched" && ! "$since" < "$switched" ]] && claude_running; then
    already=true
  fi
  if [[ "$already" != true ]]; then
    echo ""
    if claude_running; then
      echo "In Claude Desktop: quit it (Claude > Quit Claude, or ⌘Q) and open it again, so it starts the"
      echo "$ENTRY_NAME entry."
    elif [[ "${SNYK_INSTALL_NO_OPEN:-}" == "1" ]]; then
      print_step "Would open: open -a $(printf '%q' "$claude_app")"
    else
      print_step "Opening Claude Desktop..."
      open -a "$claude_app" || print_warning "Couldn't open Claude Desktop. Open it yourself."
    fi
    echo ""
  fi
  local ready=false waited=0
  while [[ "$already" != true ]]; do
    read -r srv since err <<<"$(server_state "$entry_log")"
    if [[ "$srv" == running && ! "$since" < "$start_ts" ]]; then
      ready=true
      break
    fi
    if [[ "$srv" == failed && ! "$since" < "$start_ts" ]]; then break; fi
    [[ "$waited" -lt "$wait_secs" ]] || break
    [[ "$waited" -ne 0 ]] || print_step "Waiting for Claude Desktop to start the $ENTRY_NAME entry (up to $((wait_secs / 60)) minutes)..."
    touch "$SNYK_TEMP_DIR" 2>/dev/null || true
    sleep 2
    waited=$((waited + 2))
  done

  echo ""
  if [[ "$already" == true ]]; then
    print_success "Already up to date and running: the $ENTRY_NAME entry, release $release"
  elif [[ "$ready" == true ]]; then
    print_success "Installed and running: the $ENTRY_NAME entry, release $release"
  elif [[ "$srv" == failed && ! "$since" < "$start_ts" ]]; then
    print_error "Claude Desktop started the $ENTRY_NAME entry, but it failed${err:+: $err}"
    print_error "Quit and reopen Claude Desktop; if it still fails, see ~/Library/Logs/Claude/mcp-server-$ENTRY_NAME.log."
    exit 1
  elif [[ "$wait_secs" -eq 0 ]]; then
    print_success "Done. Quit Claude Desktop (⌘Q) and open it again if it was open, so it starts the $ENTRY_NAME"
    echo "entry, then start a new chat."
    echo ""
    echo "Check the install any time with:"
    echo "  $status_cmd"
    return 0
  else
    print_error "Claude Desktop hasn't started the $ENTRY_NAME entry within $((wait_secs / 60)) minutes."
    print_error "Quit Claude Desktop (⌘Q) and open it again, then check with the --status command below."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  fi
  echo ""
  echo "Next: start a new chat in Claude Desktop (chats opened before the entry was running don't see its tools)"
  echo "and ask \"Which of my repos have the most critical issues?\"."
  if ! signin_saved; then
    echo "No Snyk token is saved yet: Claude will show a card that explains how to create one and takes it."
  fi
  echo "Ask Claude to \"show my Snyk settings\" to change the settings (write tools, update check and more)."
  echo ""
  echo "Check the install any time with:"
  echo "  $status_cmd"
}

# --entry --uninstall: removes the snyk-mcp entry from Claude Desktop's config (only one that runs the installed
# release; a backup is kept) and the installed release. Settings and the saved Snyk token are kept. A config it can't
# read changes nothing at all: removing the release alone would leave an entry that runs nothing.
uninstall_entry() {
  local claude_support="$1" yes="$2"
  local cfg server_dir launcher cfg_state has_release=false
  server_dir="$(entry_data_dir)/server"
  launcher="$server_dir/$LAUNCHER_NAME"
  if ! cfg="$(config_target "$claude_support/claude_desktop_config.json")"; then
    die "$(config_problem link): $cfg. Nothing was changed: an entry in it may still run the release. Fix the link, then run this again"
  fi
  cfg_state="$(config_state "$cfg" "$launcher")"
  case "$cfg_state" in
    invalid | unreadable | error)
      die "$(config_problem "$cfg_state"): $cfg. Nothing was changed: an entry in it may still run the release. Fix it (Claude Desktop needs to read it too), then run this again"
      ;;
  esac
  if [[ -f "$launcher" && -d "$server_dir/versions" ]]; then has_release=true; fi
  if [[ "$cfg_state" != ours && "$has_release" != true ]]; then
    [[ "$cfg_state" != other ]] || print_warning "Claude Desktop's $ENTRY_NAME entry runs something else; leaving it alone."
    die "Nothing to remove: no $ENTRY_NAME entry from this installer and no release in $server_dir"
  fi
  local what=()
  [[ "$cfg_state" != ours ]] || what+=("the $ENTRY_NAME entry in Claude Desktop's config (a backup is kept)")
  [[ "$has_release" != true ]] || what+=("the installed release in $server_dir")
  local question
  question="Remove $(printf '%s and ' "${what[@]}")"
  question="${question% and }?"
  if [[ "$yes" != true ]] && ! ask_yes_no "$question"; then
    die "Not removed (with no terminal, add --yes: $(again_with --yes))"
  fi
  if [[ "$cfg_state" == ours ]]; then
    local backup
    backup="$(write_config remove "$cfg" "$launcher")" || exit 1
    print_success "Removed the $ENTRY_NAME entry from Claude Desktop's config${backup:+ (backup: $backup)}"
  elif [[ "$cfg_state" == other ]]; then
    print_warning "Claude Desktop's $ENTRY_NAME entry runs something else; left it alone."
  fi
  if [[ "$has_release" == true ]]; then
    rm -rf "${server_dir:?}"
    print_success "Removed $server_dir"
  fi
  echo "Quit Claude Desktop and open it again. Your settings ($(entry_data_dir)/settings.toml) are kept, and so is"
  echo "the saved Snyk token: to remove it too, ask Claude to \"Sign out of Snyk\" before this, or delete the"
  echo "$KEYCHAIN_SERVICE items in Keychain Access."
}

main() {
  [[ -n "${HOME:-}" ]] || die "HOME isn't set, so the installer can't find your home folder"
  SNYK_ARGS=("$@")
  local dir="" status_only=false uninstall=false yes=false no_wait=false set_token_only=false entry=false
  local install_uv_ok=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --entry)
        entry=true
        shift
        ;;
      --install-uv)
        install_uv_ok=true
        shift
        ;;
      --dir)
        [[ $# -ge 2 && -n "$2" ]] || die "--dir needs a folder path"
        dir="$2"
        shift 2
        ;;
      --dir=*)
        dir="${1#--dir=}"
        [[ -n "$dir" ]] || die "--dir needs a folder path"
        shift
        ;;
      --status)
        status_only=true
        shift
        ;;
      --no-wait)
        no_wait=true
        shift
        ;;
      --set-token)
        set_token_only=true
        shift
        ;;
      --uninstall)
        uninstall=true
        shift
        ;;
      --yes | -y)
        yes=true
        shift
        ;;
      --help | -h)
        usage
        exit 0
        ;;
      *) die "Unknown argument: $1 (try --help)" ;;
    esac
  done

  [[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS only: the extension runs in Claude Desktop on a Mac"
  if [[ "$install_uv_ok" == true && ("$entry" != true || "$uninstall" == true || "$status_only" == true) ]]; then
    die "--install-uv goes with --entry: the mcpServers entry is what needs uv"
  fi

  local default_dir="${HOME%/}/.snyk-mcp"
  [[ -n "$dir" ]] || dir="${SNYK_MCP_HOME:-$default_dir}"
  # Expand a leading ~ (the shell doesn't when the path arrives quoted or via the environment).
  if [[ "$dir" == \~ || "$dir" == \~/* ]]; then dir="$HOME${dir:1}"; fi
  dir="${dir%/}"
  [[ "$dir" == /* ]] || die "The download folder must be an absolute path: $dir"
  case "/$dir/" in
    */../* | */./*) die "The download folder can't contain . or .. segments: $dir" ;;
  esac
  # Compare physical, lower-cased paths: macOS volumes are case-insensitive by default.
  local canon canon_home p
  canon="$(lowercase "$(canonical_path "$dir")")" || die "Can't resolve the download folder: $dir"
  canon_home="$(lowercase "$(canonical_path "$HOME")")" || die "Can't resolve your home folder"
  [[ "$canon" != "$canon_home" ]] || die "Can't use your home folder itself as the download folder"
  # Your own temporary folder lives under /var on macOS (/var/folders/.../T); it isn't a system location.
  local user_tmp
  user_tmp="$(getconf DARWIN_USER_TEMP_DIR 2>/dev/null || true)"
  if [[ -n "$user_tmp" ]]; then user_tmp="$(lowercase "$(canonical_path "${user_tmp%/}")")" || user_tmp=""; fi
  if [[ -z "$user_tmp" || "$user_tmp" == "/" || ("$canon" != "$user_tmp" && "$canon" != "$user_tmp/"*) ]]; then
    for p in /Applications /System /Library /usr /bin /sbin /etc /private/etc /var /opt; do
      [[ -d "$p" ]] || continue
      local canon_p
      canon_p="$(lowercase "$(canonical_path "$p")")"
      if [[ "$canon" == "$canon_p" || "$canon" == "$canon_p/"* ]]; then
        die "Can't use a system location as the download folder: $dir"
      fi
    done
  fi

  SNYK_INSTALL_TTY_PATH="${SNYK_INSTALL_TTY:-/dev/tty}"
  local claude_app="${SNYK_CLAUDE_APP:-/Applications/Claude.app}"
  local claude_support="${HOME%/}/Library/Application Support/Claude"
  # Claude Desktop's own log for this extension's server (named after its display name).
  local log_file="${HOME%/}/Library/Logs/Claude/mcp-server-$APP_TITLE.log"
  local base="${SNYK_INSTALL_BASE:-$SITE_BASE_DEFAULT}"
  base="${base%/}"
  # Under curl | bash there is no local install.sh, so the pointers to --status spell out the whole command.
  # Every value is shell-quoted (printf %q) so the printed command can be pasted even when a path holds a
  # space, $, backtick, quote or backslash.
  local q_base q_dir status_cmd entry_cmd
  printf -v q_base '%q' "$base"
  printf -v q_dir '%q' "$dir"
  status_cmd="curl -fsSL $q_base/install.sh | bash -s -- --status"
  entry_cmd="curl -fsSL $q_base/install.sh | bash -s -- --entry"
  if [[ "$dir" != "$default_dir" ]]; then
    status_cmd+=" --dir $q_dir"
    entry_cmd+=" --dir $q_dir"
  fi
  local var q_value arg q_arg
  SNYK_AGAIN="curl -fsSL $q_base/install.sh |"
  for var in SNYK_INSTALL_TTY SNYK_MCP_HOME SNYK_MCP_DATA_DIR SNYK_INSTALL_BASE; do
    if [[ -n "${!var+set}" ]]; then
      printf -v q_value '%q' "${!var}"
      SNYK_AGAIN+=" $var=$q_value"
    fi
  done
  SNYK_AGAIN+=" bash -s --"
  for arg in "${SNYK_ARGS[@]+"${SNYK_ARGS[@]}"}"; do
    printf -v q_arg '%q' "$arg"
    SNYK_AGAIN+=" $q_arg"
  done

  if [[ "$status_only" == true ]]; then
    print_status "$dir" "$base" "$claude_app" "$claude_support" "$log_file" "$entry_cmd"
    return 0
  fi

  local tool
  if [[ "$set_token_only" == true ]]; then
    for tool in curl security; do
      command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"
    done
    can_answer || die "--set-token needs a terminal to ask for the token (the token must never be typed into a chat)"
    set_token "Add or replace your Snyk token." || die "No token was saved"
    echo "Start a new chat in Claude Desktop, or just ask Claude something: it picks the new token up at once."
    return 0
  fi

  # The entry's data folder must be absolute: the release installs itself from a temporary folder, which a relative
  # one would point into.
  if [[ "$entry" == true && "$(entry_data_dir)" != /* ]]; then
    die "SNYK_MCP_DATA_DIR must be an absolute path (or start with ~/), not $(entry_data_dir). Nothing was changed"
  fi

  if [[ "$uninstall" == true && "$entry" == true ]]; then
    uninstall_entry "$claude_support" "$yes"
    return 0
  fi

  if [[ "$uninstall" == true ]]; then
    [[ -d "$dir" ]] || die "Nothing to remove: $dir doesn't exist"
    [[ -e "$dir/.snyk-mcp-home" ]] || die "$dir isn't an $APP_TITLE download folder; leaving it alone"
    if [[ "$yes" != true ]] && ! ask_yes_no "Remove $dir?"; then
      die "Not removed (with no terminal, add --yes: $(again_with --yes))"
    fi
    rm -rf "${dir:?}"
    print_success "Removed $dir"
    echo "The extension itself is managed by Claude Desktop. To remove it, first ask Claude to \"Sign out of"
    echo "Snyk\" (that deletes the saved token from your Keychain), then uninstall it in Settings > Extensions."
    return 0
  fi

  echo ""
  if [[ "$entry" == true ]]; then
    print_step "Installing $APP_TITLE as a Claude Desktop mcpServers entry ($ENTRY_NAME)"
  else
    print_step "Installing $APP_TITLE for Claude Desktop"
  fi
  echo ""

  print_step "Checking prerequisites..."
  local uv=""
  for tool in curl awk osascript open security; do
    command -v "$tool" >/dev/null 2>&1 || die "$tool is not available"
  done
  command -v sha256sum >/dev/null 2>&1 || command -v shasum >/dev/null 2>&1 || die "Neither sha256sum nor shasum is available"
  if [[ "$entry" == true ]]; then
    command -v unzip >/dev/null 2>&1 || die "unzip is not available"
  fi
  [[ -d "$claude_app" ]] || die "Claude Desktop not found at $claude_app. Install it from https://claude.ai/download, then run this again"
  local app_version
  app_version="$(claude_version "$claude_app")"
  if [[ -z "$app_version" ]]; then
    print_warning "Couldn't read Claude Desktop's version; the extension needs $MIN_CLAUDE_VERSION or later"
  elif ! version_ge "$app_version" "$MIN_CLAUDE_VERSION"; then
    die "Claude Desktop $app_version is too old: the extension needs $MIN_CLAUDE_VERSION or later. Update Claude Desktop (Claude > Check for Updates), then run this again"
  fi
  print_success "macOS and Claude Desktop ${app_version:-found}"

  # --entry: every check and question comes first, before anything is downloaded or installed.
  local need_uv=false cfg_consent=false
  if [[ "$entry" == true ]]; then
    # The entry installs only stable releases (snyk_mcp/managed.py); the pre-release site serves others.
    local site_version
    site_version="$(curl -fsSL "$base/latest.version" 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$site_version" == *-* ]]; then
      die "This site serves a pre-release ($site_version), and the $ENTRY_NAME entry installs only stable releases. Nothing was changed. Use the stable site: curl -fsSL $SITE_BASE_STABLE/install.sh | bash -s -- --entry"
    fi
    # uv: the entry runs with it. Installing software is the owner's call: a question in a terminal, else
    # --install-uv (their go-ahead). It is installed only once the download has been checked, below.
    uv="$(find_uv)"
    if [[ -z "$uv" ]]; then
      local how
      how="$(uv_install_how)"
      print_warning "uv isn't installed, and the $ENTRY_NAME entry runs with it."
      if [[ "$install_uv_ok" == true ]] || ask_yes_no "Install uv now, $how?"; then
        need_uv=true
      elif can_answer; then
        die "uv wasn't installed, so nothing was changed. Install it yourself (brew install uv, or see https://docs.astral.sh/uv/getting-started/installation/), then run this again"
      else
        die "Nothing was changed. With the user's go-ahead to install uv $how, run: $(again_with --install-uv)  (or they install uv themselves: brew install uv, or https://docs.astral.sh/uv/getting-started/installation/)"
      fi
    else
      print_success "uv: $uv"
    fi
    # Claude Desktop's config: the owner's go-ahead to change it, now rather than after a minute of installing.
    local cfg_path pre_state question
    if ! cfg_path="$(config_target "$claude_support/claude_desktop_config.json")"; then
      die "$(config_problem link), so nothing was changed: $cfg_path. Fix the link, then run this again"
    fi
    pre_state="$(config_state "$cfg_path" "$(entry_data_dir)/server/$LAUNCHER_NAME")"
    case "$pre_state" in
      ours) cfg_consent=true ;;
      none | missing | other)
        if [[ "$pre_state" == other ]]; then
          question="Claude Desktop's $ENTRY_NAME entry runs something else. Point it at this release ($cfg_path; a backup is kept)?"
        else
          question="Add the $ENTRY_NAME entry to Claude Desktop's config ($cfg_path; a backup is kept)?"
        fi
        if [[ "$yes" == true ]] || ask_yes_no "$question"; then
          cfg_consent=true
        elif ! can_answer; then
          die "Nothing was changed. With the user's go-ahead to change Claude Desktop's config, run: $(again_with --yes)"
        fi
        ;;
      *)
        die "$(config_problem "$pre_state"), so nothing was changed: $cfg_path. Fix it (Claude Desktop needs to read it too), then run this again"
        ;;
    esac
  fi

  # The folder must be new, empty, or one of ours.
  if [[ -e "$dir" && ! -d "$dir" ]]; then die "Not a folder: $dir"; fi
  if [[ -d "$dir" ]]; then
    if [[ ! -e "$dir/.snyk-mcp-home" && -n "$(find "$dir" -mindepth 1 -maxdepth 1 ! -name .DS_Store 2>/dev/null)" ]]; then
      die "That folder is not empty and isn't an $APP_TITLE download folder: $dir"
    fi
    [[ -w "$dir" ]] || die "That folder isn't writable: $dir"
  else
    mkdir -p "$dir" || die "Couldn't create $dir"
    chmod 700 "$dir" || die "Couldn't set permissions on $dir"
  fi
  # Mark the folder as ours straight away, so a re-run after an interruption recognises it.
  touch "$dir/.snyk-mcp-home"
  # A run that was killed outright (no clean-up) leaves its temporary folder; a running one keeps its own fresh.
  find "$dir" -mindepth 1 -maxdepth 1 -type d -name '.download.*' -mtime +0 -exec rm -rf {} + 2>/dev/null || true
  print_success "Download folder: $dir"

  # Download into a temp folder and verify before anything is changed.
  SNYK_TEMP_DIR="$(mktemp -d "$dir/.download.XXXXXX")" || die "Couldn't create a temporary folder"
  trap cleanup_temp EXIT

  print_step "Downloading the latest release..."
  curl -fsSL "$base/latest.mcpb" -o "$SNYK_TEMP_DIR/latest.mcpb" || die "Download failed: $base/latest.mcpb"
  curl -fsSL "$base/latest.mcpb.sha256" -o "$SNYK_TEMP_DIR/latest.mcpb.sha256" || die "Download failed: $base/latest.mcpb.sha256"
  local version=""
  if curl -fsSL "$base/latest.version" -o "$SNYK_TEMP_DIR/latest.version" 2>/dev/null; then
    version="$(tr -d '[:space:]' <"$SNYK_TEMP_DIR/latest.version")"
  fi
  [[ -z "$version" || "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$ ]] || die "The site's latest.version isn't a version number"

  local expected actual
  expected="$(awk 'NR == 1 { print tolower($1) }' "$SNYK_TEMP_DIR/latest.mcpb.sha256")"
  actual="$(sha256_of "$SNYK_TEMP_DIR/latest.mcpb")"
  if [[ ! "$expected" =~ ^[0-9a-f]{64}$ || "$expected" != "$actual" ]]; then
    print_error "Checksum mismatch — nothing was installed"
    print_error "Expected: ${expected:-<none>}"
    print_error "Got:      $actual"
    print_error "This can happen for up to about 10 minutes while a new release propagates; wait and run the installer again."
    exit 1
  fi
  print_success "Downloaded and verified${version:+ version $version}"

  mv -f "$SNYK_TEMP_DIR/latest.mcpb" "$dir/latest.mcpb"
  mv -f "$SNYK_TEMP_DIR/latest.mcpb.sha256" "$dir/latest.mcpb.sha256"
  if [[ -n "$version" ]]; then mv -f "$SNYK_TEMP_DIR/latest.version" "$dir/latest.version"; fi

  # How long to wait for Claude Desktop: until the extension (or the entry) is installed and running.
  local wait_secs="${SNYK_INSTALL_WAIT_SECS:-}"
  if [[ -z "$wait_secs" ]]; then
    if [[ "${SNYK_INSTALL_NO_OPEN:-}" == "1" ]]; then wait_secs=0; else wait_secs=600; fi
  fi
  [[ "$wait_secs" =~ ^[0-9]+$ ]] || die "SNYK_INSTALL_WAIT_SECS must be a whole number of seconds"
  if [[ "$no_wait" == true ]]; then wait_secs=0; fi

  if [[ "$entry" == true ]]; then
    if [[ "$version" == *-* ]]; then
      die "This site serves a pre-release ($version), and the $ENTRY_NAME entry installs only stable releases. The verified download is kept in $dir; nothing else was changed"
    fi
    # The Snyk token, as for the extension: asked for in a terminal when none is saved; never without one.
    token_step "$base" "$dir"
    if [[ "$need_uv" == true ]]; then
      install_uv || die "uv wasn't installed, so the entry wasn't set up (only the verified download is kept, in $dir). Install uv yourself (see https://docs.astral.sh/uv/getting-started/installation/), then run this again"
      uv="$(find_uv)"
      [[ -n "$uv" ]] || die "uv was installed, but the installer can't find it (looked in your PATH, /opt/homebrew/bin, /usr/local/bin and ~/.local/bin)"
      print_success "uv: $uv"
    fi
    install_entry "$dir" "$version" "$uv" "$claude_app" "$claude_support" "$cfg_consent" "$wait_secs" "$status_cmd"
    return 0
  fi

  local before before_version before_enabled _org _writes
  before="$(claude_extension_state "$claude_support")"
  read -r before_version before_enabled _org _writes <<<"$before"

  # Installing again doesn't help when the organisation blocks the extension: say what does, before asking for the
  # token or opening Claude Desktop's install dialog.
  if [[ "$before_enabled" == blocked ]]; then
    print_error "Claude Desktop has $APP_TITLE $before_version, but your organisation blocks the extension."
    blocked_hint "$entry_cmd" >&2
    exit 1
  fi

  # The Snyk token comes first, so a typo can be corrected here rather than in the chat. Skipped when one is saved.
  token_step "$base" "$dir"

  # Server starts logged from now on belong to this install.
  local start_ts
  start_ts="$(date -u '+%Y-%m-%dT%H:%M:%S')"

  local already=false
  if [[ -n "$version" && "$before_version" == "$version" ]]; then
    already=true
  elif [[ "${SNYK_INSTALL_NO_OPEN:-}" == "1" ]]; then
    print_step "Would open: open -a $(printf '%q' "$claude_app") $(printf '%q' "$dir/latest.mcpb")"
  else
    print_step "Opening Claude Desktop's install dialog..."
    open -a "$claude_app" "$dir/latest.mcpb" ||
      print_warning "Couldn't open it automatically. Double-click $dir/latest.mcpb to install it."
  fi

  if [[ "$already" != true ]]; then
    echo ""
    echo "In Claude Desktop:"
    if [[ "$before_version" == none ]]; then
      echo "  1. Click Install. You can leave the settings blank."
      echo "  2. If Claude Desktop shows the extension switched off, switch it on: Settings > Extensions >"
      echo "     $APP_TITLE (click once, then wait a few seconds)."
    else
      if [[ -n "$version" ]] && version_older "$version" "$before_version"; then
        echo "  Click Install to replace $before_version with $version, an earlier version. Your settings and your"
        echo "  Snyk token are kept."
      else
        echo "  Click Install to update from $before_version. Your settings and your Snyk token are kept."
      fi
    fi
    echo ""
  fi

  # Wait until the extension is installed at this version, switched on and running: Claude Desktop's list says the
  # first two, its log for the extension says whether the server started after this install.
  if [[ "$already" == true ]]; then wait_secs=0; fi
  local state ext_version enabled org writes srv since err listed ready=false open waited=0
  local hinted_off=false hinted_start=false
  while :; do
    state="$(claude_extension_state "$claude_support")"
    read -r ext_version enabled org writes <<<"$state"
    read -r srv since err <<<"$(server_state "$log_file")"
    open=false
    claude_running && open=true
    listed=false
    if [[ "$ext_version" != none ]]; then
      if [[ -n "$version" && "$ext_version" == "$version" ]] ||
        [[ -z "$version" && ("$already" == true || "$ext_version" != "$before_version") ]]; then listed=true; fi
    fi
    if [[ "$listed" == true && "$enabled" != disabled && "$enabled" != blocked && "$open" == true && "$srv" == running ]] &&
      [[ "$already" == true || ! "$since" < "$start_ts" ]]; then
      ready=true
      break
    fi
    if [[ "$listed" == true && "$enabled" == blocked ]]; then break; fi
    [[ "$waited" -lt "$wait_secs" ]] || break
    [[ "$waited" -ne 0 ]] || print_step "Waiting for you to finish in Claude Desktop (up to $((wait_secs / 60)) minutes)..."
    if [[ "$listed" == true && "$enabled" == disabled && "$hinted_off" != true && "$waited" -ge 4 ]]; then
      print_warning "Claude Desktop installed it, but the extension is switched off."
      switch_on_hint
      hinted_off=true
    fi
    if [[ "$listed" == true && "$enabled" == enabled && "$srv" == starting && "$hinted_start" != true ]]; then
      print_step "Claude Desktop is starting the extension (the first start downloads Python and the dependencies, about a minute)..."
      hinted_start=true
    fi
    # Keep the temp folder fresh so nothing mistakes a long wait for a leftover.
    touch "$SNYK_TEMP_DIR" 2>/dev/null || true
    sleep 2
    waited=$((waited + 2))
  done

  # Claude Desktop can still remove or switch off an extension right after installing it (Settings > Extensions):
  # look again after a few seconds.
  if [[ "$ready" == true && "$already" != true && "$wait_secs" -gt 0 ]]; then
    local settle="${SNYK_INSTALL_SETTLE_SECS:-5}"
    [[ "$settle" =~ ^[0-9]+$ ]] || settle=5
    sleep "$settle"
    read -r ext_version enabled org writes <<<"$(claude_extension_state "$claude_support")"
    if [[ "$ext_version" == none ]]; then
      echo ""
      print_error "Claude Desktop removed the extension again just after installing it (Settings > Extensions > Uninstall?)."
      print_error "Run the install command again, and leave the extension installed and switched on."
      exit 1
    fi
    if [[ "$enabled" == blocked ]]; then
      echo ""
      print_error "The extension was installed, then switched off: your organisation blocks it."
      blocked_hint "$entry_cmd" >&2
      exit 1
    fi
    if [[ "$enabled" == disabled ]]; then
      echo ""
      print_error "The extension was installed, then switched off again."
      switch_on_hint >&2
      exit 1
    fi
  fi

  echo ""
  local summary
  summary="$APP_TITLE $(describe_extension "$ext_version" "$enabled" "$org")"
  if [[ "$ready" == true ]]; then
    if [[ "$already" == true ]]; then
      print_success "Already up to date and running: $summary"
    else
      print_success "Installed and running: $summary"
    fi
    if [[ "$writes" == writes-on ]]; then
      echo "Write tools are on: Claude can import repos, ignore issues and change projects in Snyk (it shows you"
      echo "what it will do first). Turn them off in Settings > Extensions > $APP_TITLE > Configure."
    fi
    # The mcpServers entry from --entry, if it is there too, would give Claude every tool twice.
    local entry_cfg
    if entry_cfg="$(config_target "$claude_support/claude_desktop_config.json")" &&
      [[ "$(config_state "$entry_cfg" "$(entry_data_dir)/server/$LAUNCHER_NAME")" == ours ]]; then
      print_warning "The $ENTRY_NAME mcpServers entry is set up too, so Claude would see every tool twice. Keep one:"
      echo "  remove the entry with: curl -fsSL $q_base/install.sh | bash -s -- --entry --uninstall"
      echo "  or switch the extension off in Settings > Extensions > $APP_TITLE."
    fi
    echo ""
    echo "Next: start a new chat in Claude Desktop (chats opened before the extension was on don't see its tools)"
    echo "and ask \"Which of my repos have the most critical issues?\"."
    if ! signin_saved; then
      echo "No Snyk token is saved yet: Claude will show a card that explains how to create one and takes it."
    fi
  elif [[ "$listed" == true && "$enabled" == blocked ]]; then
    print_error "Claude Desktop installed $APP_TITLE $ext_version, but your organisation blocks the extension."
    blocked_hint "$entry_cmd" >&2
    exit 1
  elif [[ "$listed" == true && "$enabled" == disabled && ("$wait_secs" -gt 0 || "$already" == true) ]]; then
    print_error "Claude Desktop has $summary, but the extension is switched off:"
    switch_on_hint >&2
    exit 1
  elif [[ "$listed" == true && "$open" != true ]]; then
    print_warning "Claude Desktop has $summary, but Claude Desktop isn't open. Open it to start the extension."
  elif [[ "$listed" == true && "$srv" == failed && ("$wait_secs" -gt 0 || "$already" == true) ]]; then
    print_error "Claude Desktop has $summary, but its server failed to start${err:+: $err}"
    print_error "Run the install command again; if it still fails, see ~/Library/Logs/Claude/mcp-server-$APP_TITLE.log."
    exit 1
  elif [[ "$listed" == true && "$wait_secs" -gt 0 ]]; then
    print_error "Claude Desktop has $summary, but hasn't started it within $((wait_secs / 60)) minutes."
    print_error "Check again in a minute with the --status command below; if it still hasn't started, run the install command again."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  elif [[ "$listed" == true ]]; then
    print_success "Claude Desktop has $summary. It isn't running yet: check again in a minute with the --status command below."
  elif [[ "$wait_secs" -eq 0 ]]; then
    print_success "Done. Finish in Claude Desktop: click Install and make sure the extension is switched on. Then"
    echo "start a new chat."
  else
    print_error "Claude Desktop doesn't list version ${version:-the new version} yet."
    print_error "If you closed the install dialog, run the install command again; or double-click $dir/latest.mcpb."
    echo "Check the install any time with:"
    echo "  $status_cmd"
    exit 1
  fi
  echo ""
  echo "Check the install any time with:"
  echo "  $status_cmd"
}

main "$@"
