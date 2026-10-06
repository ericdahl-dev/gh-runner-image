#!/bin/sh
# Mondays: email a 7-day summary of ger3 load and runner use, from the samples
# ci-load-sample collects. Mail goes through the mail-bridge on the coolify network
# (ger3 blocks outbound SMTP). Needs /etc/ci-load-report.env (root, 600) with
# MAIL_BRIDGE_SMTP_PASSWORD and REPORT_TO, and optionally GH_BILLING_PAT (fine-grained,
# org Administration: read) to add GitHub-hosted Actions minutes for the month.
# Installed as /usr/local/bin/ci-load-report, cron in /etc/cron.d/ci-load-report.
set -eu
. /etc/ci-load-report.env
LOG=/var/log/ci-load.tsv
CORES=$(nproc)
since=$(( $(date +%s) - 7*86400 ))

summary=$(awk -v s="$since" -v cores="$CORES" '
  $1 >= s {
    n++; sum += $3; if ($3 > peak) { peak = $3; peakt = $1 }
    if ($3 > cores) over++
    b = $4 + $5; if (b > 0) anyb++; if (b == 2) both++
  }
  END {
    if (n == 0) { print "No samples in the last 7 days."; exit }
    printf "Samples: %d (every 5 minutes)\n\n", n
    printf "Load (5-min average) on %d cores\n", cores
    printf "  average: %.2f\n", sum / n
    printf "  peak:    %.2f at %s UTC\n", peak, strftime("%a %Y-%m-%d %H:%M", peakt, 1)
    printf "  above %d: %.1f%% of the time\n\n", cores, 100 * over / n
    printf "Runners\n"
    printf "  at least one busy: %.1f%% of the time (~%.1f hours)\n", 100 * anyb / n, anyb * 5 / 60
    printf "  both busy:         %.1f%% of the time (~%.1f hours)\n\n", 100 * both / n, both * 5 / 60
    printf "Both busy is when new jobs queue. If it is a large share, or load often\n"
    printf "sits above the core count, revisit runner count or limits.\n"
  }' "$LOG")

if [ -n "${GH_BILLING_PAT:-}" ]; then
  y=$(date -u +%Y); m=$(date -u +%-m)
  # Public repos' minutes are free and don't use the included 3,000, so leave them out.
  public=$(curl -fsS "https://api.github.com/orgs/ericdahl-dev/repos?type=public&per_page=100" \
    | python3 -c 'import json,sys; print(" ".join(r["name"] for r in json.load(sys.stdin)))') || public=""
  minutes=$(curl -fsS -H "Authorization: Bearer $GH_BILLING_PAT" -H "Accept: application/vnd.github+json" \
      "https://api.github.com/organizations/ericdahl-dev/settings/billing/usage?year=$y&month=$m" \
    | PUBLIC="$public" python3 -c '
import json, os, sys, collections
public = set(os.environ["PUBLIC"].split())
items = [i for i in json.load(sys.stdin)["usageItems"]
         if i["unitType"] == "Minutes" and i["repositoryName"] not in public]
by_repo = collections.Counter(); linux = paid = 0.0
for i in items:
    by_repo[i["repositoryName"]] += i["quantity"]
    if i["sku"] == "Actions Linux": linux += i["quantity"]
    paid += i["netAmount"]
print(f"Private-repo Linux minutes this month: {linux:.0f} of 3,000 included")
print(f"Billed this month: ${paid:.2f} (macOS/Windows and any overage)")
print("Top private repos: " + ", ".join(f"{r} {q:.0f}" for r, q in by_repo.most_common(5)))
' 2>&1) || minutes="(billing API call failed)"
  summary=$(printf '%s\n\nGitHub-hosted Actions (ger3 runs are free and not counted)\n%s\n' "$summary" "$minutes")
fi

body=$(printf 'From: ger3 CI <alerts@ericdahl.dev>\r\nTo: %s\r\nSubject: ger3 CI load, week ending %s\r\n\r\n%s\r\n' \
  "$REPORT_TO" "$(date -u +%Y-%m-%d)" "$summary")

printf '%s' "$body" | docker run --rm -i --network coolify curlimages/curl:latest -sS \
  --url smtp://mail-bridge:2525 --user "glitchtip:$MAIL_BRIDGE_SMTP_PASSWORD" \
  --mail-from alerts@ericdahl.dev --mail-rcpt "$REPORT_TO" --upload-file -
echo "sent to $REPORT_TO"
