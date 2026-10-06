#!/bin/sh
# Every 5 minutes: record ger3's load and whether each runner is mid-job, for the
# weekly report. Columns: epoch load1 load5 runner1_busy runner2_busy.
# Installed as /usr/local/bin/ci-load-sample, cron in /etc/cron.d/ci-load-report.
SERVICE=h4esa4ronft1iqni8yrlu8ze
LOG=/var/log/ci-load.tsv
busy() { docker top "runner-$1-$SERVICE" -eo pid,args 2>/dev/null | grep -c '[R]unner.Worker'; }
read l1 l5 _ < /proc/loadavg
printf '%s\t%s\t%s\t%s\t%s\n' "$(date +%s)" "$l1" "$l5" "$(busy 1)" "$(busy 2)" >> "$LOG"
# Keep 35 days.
cutoff=$(( $(date +%s) - 35*86400 ))
awk -v c="$cutoff" '$1 >= c' "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
