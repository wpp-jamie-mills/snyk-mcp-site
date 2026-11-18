# Installing Snyk Projects and Issues (unofficial)

macOS only, with Claude Desktop 2.7032.0 or later. Most people only need the one command on the landing page, https://wpp-jamie-mills.github.io/snyk-mcp-site/ (published there as https://wpp-jamie-mills.github.io/snyk-mcp-site/INSTALL.md).

## The installer

```bash
curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash
```

It downloads the latest extension into `~/.snyk-mcp`, checks its SHA-256, asks for your Snyk token (hidden input; saved to your macOS Keychain through `security -i`, never on a command line), opens Claude Desktop's install dialog and waits until the extension is installed, switched on and running. Running it again updates the extension and keeps your settings and your token.

| Option | What it does |
|---|---|
| `--set-token` | Only add or replace the Snyk token: asks with hidden input, checks it with Snyk (trying each region) and saves it |
| `--status` | What is installed, whether it is switched on and running, whether a token is saved (never the token), the latest version, and the one thing left to do |
| `--no-wait` | Open the install dialog and exit without waiting for you to click Install |
| `--dir <path>` | Download folder (default `~/.snyk-mcp`) |
| `--uninstall` | Remove the download folder (asks first; add `--yes` with no terminal) |
| `--entry` | For when your organisation blocks the extension: install the same release as a Claude Desktop `mcpServers` entry instead (see below) |
| `--entry --uninstall` | Remove the `snyk-mcp` entry from Claude Desktop's config (only one that runs the installed release; a backup is kept) and the installed release. Settings and the token stay |
| `--install-uv` | With `--entry`: install uv if it is missing, without asking (the user's go-ahead, for agents and scripts) |
| `--yes` | Answer yes to removing a folder or the entry, and to adding or changing the entry in Claude Desktop's config. Installing uv is a separate yes: `--install-uv` |

With no terminal (an AI agent, a script) the installer never asks anything, so it can't take the token. Claude then shows a card in the chat the first time you ask something; or run `--set-token` in Terminal.

## As a Claude Desktop mcpServers entry (`--entry`)

```bash
curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash -s -- --entry
```

For when your organisation blocks the extension (Claude Desktop shows "Extension is not approved for your organization"). In this order, and nothing changes until every question is answered:

1. It checks the Mac and Claude Desktop, and refuses a pre-release site: the entry installs stable releases only.
2. It looks for uv (on your `PATH`, then `/opt/homebrew/bin`, `/usr/local/bin` and `~/.local/bin`). If there is none it asks whether to install it: with Homebrew if you have it (`brew install uv`), otherwise uv's own release from GitHub, checked against a SHA-256 pinned in the installer, into `~/.local/bin`. Shell profiles are never changed. With no terminal it needs `--install-uv`.
3. It asks before adding the `snyk-mcp` entry to `~/Library/Application Support/Claude/claude_desktop_config.json`, or before pointing an existing `snyk-mcp` entry that runs something else at this release (its `env` is kept). With no terminal it needs `--yes`. A file that isn't valid JSON or can't be read, or a link it can't follow (a loop, more than 20 links in a row, or a link to nothing), is left alone and the installer stops.
4. It downloads `latest.mcpb` into `~/.snyk-mcp` and checks its SHA-256.
5. It asks for your Snyk token if none is saved (hidden input), as for the extension. With no terminal it doesn't ask: Claude shows the token card in the chat.
6. It installs uv, if you agreed.
7. It runs the release's own installer (`uv run --frozen --project <the unpacked release> snyk-mcp install-release --bundle latest.mcpb`), which installs it in `~/Library/Application Support/snyk-mcp/server/versions/<version>`, points `server/current` at it and writes the entry's command, `server/snyk-mcp`. If a newer release is installed already, it says it is installing an earlier version.
8. It adds the entry: a backup to `claude_desktop_config.json.bak-<date and time>-<random>` first (beside the real file if the config is a link), every other key and the file's permissions kept. The new file is written beside the real one and renamed over it, so Claude Desktop never reads half a file. The entry runs `server/snyk-mcp` with `MCP_RUN_MODE=config`, a `PATH` that starts with uv's folder and, if you chose another data folder, `SNYK_MCP_DATA_DIR`.
9. It asks you to quit Claude Desktop (⌘Q) and open it again, and waits until Claude Desktop starts the entry (it never quits Claude Desktop itself). With `--no-wait` it exits instead.

Then start a new chat. Ask Claude to "show my Snyk settings" for the settings card (write tools, update check, export folder, Snyk CLI path, approval cards); changes apply after you quit and reopen Claude Desktop. Keep only one of the extension and the entry switched on. `--status` shows the entry's release, whether Claude Desktop's config has it and whether its server is running.

What it changes in Claude Desktop's config: only the `snyk-mcp` entry. It rewrites the file with JavaScript's JSON parser, which keeps every other key and its order except that keys made only of digits move first, and numbers beyond 2^53 lose precision (`1e400` becomes `null`); Claude Desktop's config has neither. `--entry --uninstall` takes the entry out again but leaves `"mcpServers": {}` where there was none, and a config file the installer created stays; both are harmless. If it can't read the config, `--entry --uninstall` changes nothing at all.

### The entry by hand

1. Download `latest.mcpb` and `latest.mcpb.sha256` from https://wpp-jamie-mills.github.io/snyk-mcp-site/ and check that `shasum -a 256 latest.mcpb` prints the same SHA-256.
2. Unzip it into an empty folder and run, from there, `uv run --frozen --project . snyk-mcp install-release --bundle /path/to/latest.mcpb`. It prints the entry's command on the line `Claude Desktop entry command: ...`.
3. Back up `~/Library/Application Support/Claude/claude_desktop_config.json`, add this inside its `mcpServers` object (with that command), and check the file with `python3 -m json.tool`:

   ```json
   "snyk-mcp": {
     "command": "/Users/<you>/Library/Application Support/snyk-mcp/server/snyk-mcp",
     "args": [],
     "env": { "MCP_RUN_MODE": "config", "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" }
   }
   ```

4. Quit Claude Desktop and open it again, then start a new chat.

## Making a Snyk token

1. Open https://app.snyk.io/account (your region's address if you aren't in the US) and sign in with your company single sign-on (Okta).
2. Go to Personal access tokens and click Generate new token.
3. Choose an expiry (90 days at most) and click Copy. Snyk shows it only once. You can have three tokens at a time: revoke one first if you already have three.

## By hand

Download `latest.mcpb` and `latest.mcpb.sha256` from https://wpp-jamie-mills.github.io/snyk-mcp-site/, check `shasum -a 256 latest.mcpb`, double-click the file and click Install. Then add your token with `--set-token`, or let Claude's card do it.

## Updating, rolling back and removing

- **Update:** Claude shows an update card once a day when a new version is out (turn this off with Check for updates in the extension's settings), or run the install command again. You always click Install in Claude Desktop's own dialog.
- **Roll back:** the site only serves the latest version, and older releases are kept on this project's GitHub releases page, which is private: ask the maintainer (https://github.com/wpp-jamie-mills) for one, check its SHA-256 and open it in Claude Desktop.
- **Remove:** ask Claude to "Sign out of Snyk" (deletes the token from the Keychain), uninstall the extension in Settings > Extensions, then `install.sh --uninstall`.
- **The `mcpServers` entry:** the update card's Update now installs the new release beside the running one (no install dialog); quit and reopen Claude Desktop to start it. Running the `--entry` command again also updates. Remove it with `--entry --uninstall`.

## Settings (Settings > Extensions > this extension > Configure)

| Setting | Default | What it does |
|---|---|---|
| Snyk organisation | blank | An organisation slug, name or id; blank uses your account's default |
| Enable write tools | off | Offer the tools that change your Snyk account |
| Check for updates | on | Once a day, check the landing page for a new version |
| Export folder | `~/Downloads/snyk-exports` | Where exports and scan results are written (owner-only) |
| Snyk CLI path | blank (found automatically) | For `scan_local_repo` |

There is no token setting on purpose: the token lives only in your Keychain. The `mcpServers` entry has the same settings on its settings card (ask Claude to "show my Snyk settings"), saved in `~/Library/Application Support/snyk-mcp/settings.toml`, plus one for approval cards. A variable in the entry's `env` wins and locks that setting on the card: `SNYK_MCP_ORG`, `SNYK_MCP_ALLOW_WRITES`, `SNYK_MCP_CHECK_UPDATES`, `SNYK_MCP_EXPORT_ROOT`, `SNYK_MCP_CLI_PATH`, `SNYK_MCP_APPROVALS`.
