#!/bin/sh
# Mondays: email a 7-day summary of ger3 load and runner use, from the samples
# ci-load-sample collects. Mail goes through the mail-bridge on the coolify network
# (ger3 blocks outbound SMTP). Needs /etc/ci-load-report.env (root, 600) with
# MAIL_BRIDGE_SMTP_PASSWORD and REPORT_TO.
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

body=$(printf 'From: ger3 CI <alerts@ericdahl.dev>\r\nTo: %s\r\nSubject: ger3 CI load, week ending %s\r\n\r\n%s\r\n' \
  "$REPORT_TO" "$(date -u +%Y-%m-%d)" "$summary")

printf '%s' "$body" | docker run --rm -i --network coolify curlimages/curl:latest -sS \
  --url smtp://mail-bridge:2525 --user "glitchtip:$MAIL_BRIDGE_SMTP_PASSWORD" \
  --mail-from alerts@ericdahl.dev --mail-rcpt "$REPORT_TO" --upload-file -
echo "sent to $REPORT_TO"
