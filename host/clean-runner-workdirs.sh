#!/bin/sh
# Weekly wipe of the self-hosted runners' work folders on ger3. Each runner keeps
# repo checkouts and gem/node caches in /tmp/github-runner/ger3-N between jobs;
# this resets them so they don't grow without bound.
#
# Installed on ger3 as /usr/local/bin/clean-runner-workdirs with
# /etc/cron.d/clean-runner-workdirs. A runner is paused while its folder is
# emptied so it can't pick up a job halfway through; a busy runner is retried
# every 10 minutes for up to an hour, then skipped until next week.
set -u
SERVICE=h4esa4ronft1iqni8yrlu8ze

for n in 1 2; do
  c="runner-$n-$SERVICE"
  dir="/tmp/github-runner/ger3-$n"
  for attempt in 1 2 3 4 5 6 7; do
    docker pause "$c" >/dev/null 2>&1 || { echo "$c: not running, skipped"; break; }
    if docker top "$c" -eo pid,args 2>/dev/null | grep -q '[R]unner.Worker'; then
      docker unpause "$c" >/dev/null
      echo "$c: job running (attempt $attempt)"
      [ "$attempt" -lt 7 ] && sleep 600
      continue
    fi
    before=$(du -sh "$dir" 2>/dev/null | cut -f1)
    find "$dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
    docker unpause "$c" >/dev/null
    echo "$c: cleaned $dir ($before)"
    break
  done
done
