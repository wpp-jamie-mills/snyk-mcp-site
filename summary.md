# Snyk Projects and Issues (unofficial)

**Ask Claude about your Snyk account. It lists your repos and projects with their issue counts, explains issues, plans the fixes that clear the most of them and checks whether a package is vulnerable, using your own Snyk token. It is read-only unless you turn on write tools.**

Version **0.2.0** · macOS · Claude Desktop extension (.mcpb)

- [Install: for people](#install-for-people)
- [Install: for AI agents](#install-for-ai-agents)
- [What you can do](#what-you-can-do)
- [Sign in and sign out](#sign-in-and-sign-out)
- [What it can and can't do](#what-it-can-and-cant-do)
- [Write tools](#write-tools)
- [Available tools](#available-tools)
- [Requirements](#requirements)
- [Token and privacy](#token-and-privacy)
- [Troubleshooting](#troubleshooting)
- [Update and remove](#update-and-remove)

---

## Install: for people

You need a Mac with Claude Desktop 2.7032.0 or later and a Snyk account. Open Terminal and run:

```bash
curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash
```

The installer downloads the latest extension, checks its SHA-256 before anything changes, opens Claude Desktop's
install dialog, and waits until the extension is switched on and running.

Then:

1. When the installer asks, create a token in Snyk and paste it: open https://app.snyk.io/account, sign in with your company single sign-on (Okta), go to Personal access tokens, click Generate new token, pick an expiry (90 days at most) and copy it. You can skip this and add the token later.
2. Click Install in the dialog Claude Desktop opens. You can leave its settings blank.
3. If Claude Desktop shows the extension switched off, switch it on: Settings > Extensions > Snyk Projects and Issues (unofficial). Click once and wait a few seconds; the installer says when it is running.
4. Start a new chat (chats opened before the extension was on don't see its tools) and ask something, for example "Which of my repos have the most critical issues?".

After that it keeps itself up to date: once a day it checks for a new version, and Claude offers it on an update card
in the chat. Click Update now, then Install in Claude Desktop's dialog; nothing is installed until you do. Running the
same command again also updates. Your settings and your Snyk token are kept.

## Install: for AI agents

Use these steps if you are an AI agent installing this for a user.

1. **Check the machine.** Continue only if `uname -s` prints `Darwin` and `/Applications/Claude.app` exists. Otherwise tell the user it needs a Mac with Claude Desktop 2.7032.0 or later.
2. **Run the installer** with this one command. It downloads the extension, checks its SHA-256 (nothing changes before the check passes) and opens Claude Desktop's install dialog. With no terminal it never prompts, and `--no-wait` makes it exit once the dialog is open. It exits non-zero, with the reason on stderr, if anything fails.

```bash
curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | SNYK_INSTALL_TTY=/dev/null bash -s -- --no-wait
```

3. **Hand over to the user.** Ask them to click Install in the dialog Claude Desktop opened (they can leave its settings blank), and to switch the extension on if Claude Desktop shows it off (Settings > Extensions). You can't do these for them.
4. **Verify.** Run the installer again with `--status` (after `bash -s --`). It should show `Ready: yes`; otherwise its `Next:` line says the one thing left to do. Then ask the user to start a new chat (chats opened while the extension was off don't see its tools) and ask about their Snyk projects. If no Snyk token is saved yet, Claude shows a card where the user adds one; never ask the user to paste it to you.
5. **Updates look after themselves.** Once a day the extension checks for a new version and Claude shows the user an update card. Only the user can click Update now and then Install; to update straight away, run the install command again.

## What you can do

Ask in plain English. Claude picks the tools.

- **Scope it to your part of the estate:** "How many critical issues are in the PAM collection?", "What's the risk in `media/unified-activation`?" Collections, repos and folders (`path_prefix`) narrow every overview, list, export and fix plan, so a monorepo isn't one big number.
- **Get the answer, not the rows:** "What are the main critical risks in PAM?" comes back grouped by package and CVE (counts, projects affected, how many are fixable), biggest first, in one call. Group by package, CVE, title, repo, project, folder, month, severity or reachability.
- **See where things are:** every issue row carries the project name and manifest file, so you never decode a list of UUIDs.
- **Know what to fix first:** "Fix plan for PAM" gives the few upgrades or pins that clear the most issues, with the single version to move to (not thirteen builds of each package). Dockerfile projects get their base image and rebuild advice instead of a list of apt packages.
- **Spot false alarms:** workspace packages (`0.0.0-use.local`) are flagged, so a "malicious package" finding that is really a name collision with public npm is called out as a dependency-confusion risk, not malware. Reachability is a column and a filter.
- **Honest about fixes:** "fixable" is split into upgradable (a manifest bump), pinnable (an override or resolution) and a plain fix version, so a monorepo's overrides-fixable issues aren't hidden behind a single flag.
- **Export for analysis:** "Write every critical issue in PAM to a file" lands in `~/Downloads/snyk-exports`, where your other tools can reach it, with the full path and a summary (by severity, top packages, top projects) so a follow-up read is often unnecessary.
- **Triage:** "Explain SNYK-JS-LODASH-1018905 and how it gets into the project", "What's new since 1 November?"
- **Check packages:** "Is lodash 4.17.20 vulnerable?", "Where do we use flatted 3.2.7?", "Which projects use a GPL licence?"
- **More than one organisation:** every tool takes an `org`, and `list_orgs` shows what your token can see.
- **Scan a folder:** "Run Snyk on ~/code/my-app" (open source and infrastructure files; Snyk Code only if you ask for it).
- **With write tools on:** "Create a collection called Web from every project under `media/unified-activation`", "Rename PAM to PAM-core", "Import acme/new-service", "Ignore this issue for 30 days because the code path is unreachable", "Tag these projects team:web".

## Sign in and sign out

There is no separate sign-in: the extension uses your own Snyk **personal access token**, kept in your macOS Keychain and nowhere else. The installer asks for it the first time (hidden input).

If the token is missing, expired (Snyk tokens last at most 90 days) or rejected, Claude shows a card. It explains how to create a new one: open Snyk, sign in with your company single sign-on (Okta), go to Account settings > Personal access tokens, generate a token with an expiry of up to 90 days and copy it. Paste it into the card's hidden field and click Save. The extension checks it with Snyk, saves it to your Keychain and Claude carries on with your question. The token never appears in the chat. Claude also warns you once a day when your token has 14 days or fewer left.

You can add or replace the token without Claude: run `curl -fsSL https://wpp-jamie-mills.github.io/snyk-mcp-site/install.sh | bash -s -- --set-token` in Terminal. To sign out, ask Claude to "Sign out of Snyk" (it deletes the token from your Keychain).

## What it can and can't do

- It reads what your token can read: the organisation you choose in the settings (by default your account's default one), and nothing else. What you can change depends on your Snyk role, not on this extension.
- Lists are compact because accounts can hold thousands of projects and issues. Claude can group them on the server (`group_by`), page through them, or write everything to a file in `~/Downloads/snyk-exports` (with a summary) when it needs every row.
- Snyk can't filter issues by collection, folder or repo itself, so for those scopes this tool reads the organisation's matching issues and keeps the right ones (up to 20,000): narrowing by severity keeps it fast.
- It reads from Snyk's API; it does not scan anything itself, except through the local Snyk CLI if you have it installed.
- Snyk matches package versions exactly, so "where is this used" needs a name and a version.
- It can't open fix pull requests or retest a project on demand: Snyk's public API has no such calls (Snyk does both itself, from your project settings).
- It never deletes anything in Snyk. Write tools can add, ignore, change and deactivate, and most can be undone.
- Group-level views and webhooks need rights your token may not have; Claude says so instead of guessing.

## Write tools

Write tools are **off by default**. With the setting off they are not offered to Claude at all. Turn on **Enable write tools** in Settings > Extensions > Snyk Projects and Issues (unofficial) > Configure, and they appear under Write/delete tools in the extension's tool permissions, where you can set each one to always allow, ask first or block.

| Tool | What it does |
|---|---|
| `import_repo` | Add a repository through your GitHub or GitHub Enterprise integration; returns a job to follow |
| `import_status` | Where an import job stands |
| `ignore_issue` | Ignore one issue in one project with a reason type, a reason and (best practice) an expiry |
| `unignore_issue` | Remove an ignore |
| `update_project` | Add or remove tags, set criticality, environment and lifecycle, the test frequency or the pull request checks |
| `set_project_active` | Activate or deactivate a project (nothing is deleted) |
| `manage_collection` | Create or rename a collection, or add projects to or remove projects from one, by project id or by scope (repo, folder, type, another collection) with a preview before anything bulk is applied. Collections are never deleted |

Ignoring needs a reason (it is visible to everyone in your organisation) and Claude is told to prefer an expiry. Your Snyk role decides whether a change is allowed; Snyk's answer is shown if it isn't.

## Available tools

Read-only tools (always available):

| Tool | What it does |
|---|---|
| `whoami` | Who the token belongs to, your organisation, region, token expiry (with a warning when it is close), where exports go, and whether the Snyk CLI is installed |
| `list_orgs` | The organisations your token can see; every tool takes an `org` to use another |
| `list_repos` | Repos with project counts and latest issue counts, worst first |
| `list_projects` | Projects with their issue counts, worst first; filter by repo, collection, folder, type, status or tag; export to a file |
| `get_project` | One project's details and pull request check settings |
| `list_issues` | Issues with project name and file on every row; scope by project, repo, collection or folder; filter by type, severity, fix, reachability, workspace package or dates; `group_by` for counts per package, CVE, repo and more; export to a file |
| `get_issue` | One issue in full: scores, minimum fixed version, reachability, dependency paths or the code data flow |
| `risk_summary` | Open issues by severity, the worst repos and projects, optional grouping, and what is new since a date; scope by repo, collection or folder |
| `fix_plan` | The few upgrades and pins that clear the most issues, with the single version to move to; Dockerfile projects get their base image and rebuild advice |
| `check_packages` | Is this package version vulnerable? |
| `where_used` | Projects using a package version or a licence |
| `export_issues` | Write every matching issue to a file in `~/Downloads/snyk-exports`, with its full path and a summary |
| `export_sbom` | Write a project's SBOM (CycloneDX or SPDX) to a file |
| `search_audit_log` | Who changed or ignored what, and when |
| `list_collections` | Your collections with project and issue counts; a collection can narrow `list_projects`, `list_issues`, `risk_summary`, `fix_plan` and `export_issues` by name |
| `get_collection` | One collection: its totals and worst projects |
| `list_collection_projects` | The projects in one collection, worst first |
| `scan_local_repo` | Run the Snyk CLI on a folder on your Mac (asks first: Snyk Code uploads source) |

Token and update tools:

| Tool | What it does |
|---|---|
| `set_token` | Show the card that adds, replaces or checks your Snyk token |
| `save_token` | Used by that card's Save button: checks the token with Snyk and saves it to the Keychain |
| `token_status` | Used by that card to show where the token stands |
| `sign_out` | Delete the saved token from your Keychain |
| `check_for_updates` | Show the update card (Update now / Not now) |
| `install_update` | Used by the update card: download, check and open Claude Desktop's install dialog |
| `snooze_update` | Used by the update card: don't offer this version for a week |

## Requirements

- A Mac with Claude Desktop 2.7032.0 or later. uv is downloaded by Claude Desktop if you don't have it.
- A Snyk account, and a personal access token from it (the installer or Claude walks you through making one).
- Optional: the Snyk CLI (`brew install snyk`) for `scan_local_repo`.
- Internet access to Snyk's API (`api.snyk.io`, or your region's host).

## Token and privacy

- **Your token** lives only in your macOS login Keychain (service `snyk-mcp-pat`). It is never written to a file, a log, the chat or the extension itself. The installer, the CLI and the extension save it through `security -i` on standard input, so it never appears in the process list.
- **Where it goes:** only to Snyk's API hosts (`api.snyk.io` and the regional ones), and to the Snyk CLI through its environment when you run `scan_local_repo`. Any other address is refused before a request is made.
- **The card:** the paste field is hidden and the token is sent to the extension, checked with Snyk and saved; it isn't shown again or placed in the conversation.
- **What Claude sees:** everything Claude reads from Snyk (project names, issues, packages) is sent to Anthropic as part of your conversation. Snyk Code uploads source to Snyk, so `scan_local_repo` only runs that scan when you ask.
- **Write tools** are off by default, are not even listed while off, and are refused in three places if they are.
- **Exports** go to `~/Downloads/snyk-exports` unless you choose another folder in the settings: owner-only (mode 700, files 600), never overwritten unless you say, and a tool can't write outside it. They contain issue data from your organisation, so treat them like any other work file.
- **Updates** are checked once a day against the landing page, verified with SHA-256 and a manifest check, and installed only when you click Install in Claude Desktop's own dialog.

Report a problem with this project as described in SECURITY.md. For Snyk data handling or whether you may use this with your organisation's code, ask your security team.

## Troubleshooting

| Message or symptom | What to do |
|---|---|
| Claude shows a card asking for a Snyk token | None is saved, or Snyk rejected it (expired or revoked). Follow the card: open Snyk, sign in with your company single sign-on, create a token and paste it |
| "That token didn't work" on the card | Copy the whole token again (Snyk shows it once), check it hasn't expired, and that you made it in your own Snyk account |
| The installer says it needs a terminal for `--set-token` | Run it in Terminal yourself: the token is never typed into a chat |
| `Snyk 403` for one tool | Your Snyk role doesn't allow it; ask an organisation admin, or use another tool |
| `Snyk 429` | Snyk is throttling you; reads retry automatically, so wait a minute and ask again |
| `where_used` asks for an exact version | Snyk matches package versions exactly: give `name@version` |
| `scan_local_repo` says the CLI isn't installed | `brew install snyk`, or set its path in the extension's settings |
| The extension is listed twice in Claude Desktop | An old manual entry is still in `claude_desktop_config.json`; remove it |
| A collection or folder question is slow | Snyk can't filter issues by collection or folder, so it reads the organisation's matching issues: ask for one severity (for example critical) to keep it fast |
| Claude can't open an export | Exports are in `~/Downloads/snyk-exports` (or the folder you chose); the path returned is the real one, not a `/var` alias |
| Claude doesn't see the tools | Start a new chat after the extension is switched on |

## Update and remove

It checks for new versions itself: once a day it reads the landing page, and when there is one Claude shows an update card in the chat. **Update now** downloads the new version, checks its SHA-256 and opens Claude Desktop's install dialog; you click Install. **Not now** hides that version for a week. Turn the daily check off with **Check for updates** in the extension's settings. Running the install command again also updates. Your settings and your Snyk token are kept.

To remove it: ask Claude to "Sign out of Snyk" (this deletes the token from your Keychain), then uninstall it in Claude Desktop under Settings > Extensions. `install.sh --uninstall` removes the installer's download folder.

---

<sub>Generated from the project README for version 0.2.0. It is rebuilt automatically with each release.</sub>
