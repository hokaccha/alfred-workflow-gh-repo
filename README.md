# alfred-workflow-gh-repo

An Alfred workflow that filters the repositories of a given GitHub org / user and opens the selected one in the browser.

## Requirements

- [Alfred](https://www.alfredapp.com/) (Powerpack) 4.6 or later
- [`gh`](https://cli.github.com/) (`brew install gh`)
- Authenticated via `gh auth login`

No external `jq` is required (it uses `gh --jq`).

## Install

Double-click `gh-repo.alfredworkflow` to import it into Alfred.

Re-importing the package (same bundle id) updates the existing workflow in place.

## Configuration

Configure it via workflow environment variables. In Alfred's Workflows, select this
workflow and click the **`[𝓍]` (Workflow Environment Variables)** button in the top-right
toolbar (on Alfred 5, use **"Configure Workflow"** in the left sidebar).

| Variable | Description |
| --- | --- |
| `ORG` | The GitHub org(s) / user(s) to fetch repositories from, separated by spaces or commas, e.g. `my-org another-org` (**required**) |
| `CACHE_TTL` | Cache lifetime in seconds (default `3600`) |

When multiple orgs are given, their repositories are merged and the result list
shows `owner/name` so you can tell them apart.

If `ORG` is unset, an item prompting you to configure it is shown.

## Usage

1. Type `gh ` in Alfred to list repositories
2. Type to filter (matches both `name` and `owner/name`)
3. Press Enter to open the repository in your default browser

`gh repo list` takes a few seconds, so results are cached per org. When the cache is stale,
the previous cache is shown immediately while a refresh runs in the background (serve-stale).

## Development

```sh
# Validate the JSON output
ORG=hokaccha ./gh-repo.sh "" | python3 -m json.tool

# Error item shown when ORG is unset
unset ORG; ./gh-repo.sh ""
```
