#!/usr/bin/env bash
#
# Alfred Script Filter: returns the repository list of the given org(s)/user(s).
# ORG may list multiple orgs/users separated by spaces or commas; their repos
# are fetched and merged. Filtering is done in this script (substring match) so
# Alfred's built-in "filter results" is left off. The cache is stored as JSONL
# (one Alfred item per line) so we can grep it and still keep gh's JSON escaping
# intact. Caches per ORG value, and refreshes in the background when stale.
#
set -euo pipefail

# Alfred launches scripts with a minimal PATH, so augment it to reliably find gh
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

QUERY="${1:-}"
TTL="${CACHE_TTL:-3600}"

# Print a valid:false error item and exit normally
err() {
  printf '{"items":[{"title":"%s","subtitle":"%s","valid":false}]}\n' "$1" "$2"
  exit 0
}

[ -n "${ORG:-}" ] || err "ORG is not set" "Set one or more orgs/users (space or comma separated) in the ORG variable"
command -v gh >/dev/null 2>&1 || err "gh not found" "Install it with: brew install gh"

# Split ORG into a list on commas and/or whitespace
read -ra ORGS <<< "${ORG//,/ }"

cache_dir="${alfred_workflow_cache:-${TMPDIR:-/tmp}}"
mkdir -p "$cache_dir"
# Sanitize the ORG value for use in a filename
safe_org=${ORG//[^a-zA-Z0-9._-]/_}
cache_file="$cache_dir/repos-$safe_org.jsonl"

# Fetch each org with gh and write one Alfred item per line (JSONL), atomically
fetch() {
  local tmp="$cache_file.$$.tmp" org any=0
  : > "$tmp"
  for org in "${ORGS[@]}"; do
    [ -n "$org" ] || continue
    if gh repo list "$org" --limit 1000 --no-archived \
         --json name,nameWithOwner,description,url \
         --jq '.[] | {
           uid: .nameWithOwner,
           title: .name,
           subtitle: (if .description == "" then .nameWithOwner else .nameWithOwner + " — " + .description end),
           arg: .url,
           match: .nameWithOwner,
           autocomplete: .name
         }' >> "$tmp" 2>/dev/null; then
      any=1
    fi
  done
  if [ "$any" -eq 1 ]; then
    mv "$tmp" "$cache_file"
  else
    rm -f "$tmp"
    return 1
  fi
}

# Ensure the cache exists / is fresh
if [ -f "$cache_file" ]; then
  mtime=$(stat -f %m "$cache_file")
  if [ $(( $(date +%s) - mtime )) -gt "$TTL" ]; then
    # stale: serve current cache now, refresh in the background for next time
    ( fetch >/dev/null 2>&1 & ) &
  fi
elif ! fetch; then
  err "Failed to fetch repositories" "Check ORG and your auth with: gh auth status"
fi

# Substring filter (case-insensitive, literal). Each cache line is a full JSON
# item containing the repo name/owner/url, so grep on the line works as search.
if [ -n "$QUERY" ]; then
  lines=$(grep -iF -- "$QUERY" "$cache_file" || true)
else
  lines=$(cat "$cache_file")
fi

# Show an explicit item when nothing matches, so Alfred does not fall back
# to default results (web search, etc.)
if [ -z "$lines" ]; then
  # JSON-escape the user query before embedding it in the message
  q=${QUERY//\\/\\\\}
  q=${q//\"/\\\"}
  err "No matching repositories" "No repository in $ORG matches: $q"
fi

# Join the matching JSON lines with commas into a single items array
printf '{"items":[%s]}\n' "$(printf '%s' "$lines" | paste -sd, -)"
