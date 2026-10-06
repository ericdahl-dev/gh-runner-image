# gh-runner-image

Image for the org's self-hosted GitHub Actions runners on ger3 (`runs-on: [self-hosted, ger3]`),
deployed as Coolify service `h4esa4ronft1iqni8yrlu8ze`. Built weekly to
`ghcr.io/ericdahl-dev/gh-runner:noble`.

It is `myoung34/github-runner:ubuntu-noble` plus the system packages our CI needs (Chrome, libpq,
libvips, wkhtmltopdf's libraries, shellcheck). Ruby, Node and Python come from the `setup-*` actions.

When a repo needs something else: install it in that job if only one repo needs it, add it to the
`Dockerfile` once two do. macOS and Windows jobs stay on GitHub-hosted runners.

Two things these runners can't do, because jobs run Docker through the host's socket:

- `container:` jobs and `services:` with host ports. Start Postgres in the runner's own network
  instead (`--network container:$HOSTNAME`); see ericdahl-ops `.github/workflows/ci.yml`.
- Isolation: a job has root on ger3. The runner group is limited to private repos for that reason.

## Work folder cleanup

Runners keep repo checkouts and gem/node caches in `/tmp/github-runner/ger3-N` between jobs.
`host/clean-runner-workdirs.sh` empties them every Sunday at 04:00 UTC. It is installed on ger3 as
`/usr/local/bin/clean-runner-workdirs` with `/etc/cron.d/clean-runner-workdirs`, and logs to
`/var/log/clean-runner-workdirs.log`. Edit it here and copy it back to ger3; the host doesn't pull it.

## Weekly load report

`host/ci-load-sample.sh` runs every 5 minutes on ger3 and appends the load average and each
runner's busy state to `/var/log/ci-load.tsv` (35 days kept). `host/ci-load-report.sh` emails a 7-day
summary every Monday at 13:00 UTC, from alerts@ericdahl.dev through the `mail-bridge` container
(ger3 blocks outbound SMTP). Its settings are in `/etc/ci-load-report.env` (root only:
`MAIL_BRIDGE_SMTP_PASSWORD` from Doppler `ericdahl-dev/prd`, and `REPORT_TO`). Cron:
`/etc/cron.d/ci-load-report`, log `/var/log/ci-load-report.log`.

## Setup facts and workflow rules

- Runners: Coolify service `h4esa4ronft1iqni8yrlu8ze` on ger3, two ephemeral org runners `ger3-1`
  and `ger3-2` with `cpu_shares: 256` so the apps on ger3 win CPU contention. The registration
  token is the fine-grained PAT `GH_RUNNER_PAT` in Doppler, copied to the service's `ACCESS_TOKEN`.
- A new image only reaches the runners on a Coolify restart with `?latest=true`, and a restart
  kills running jobs: wait until both runners are idle.
- In workflows: no `services:` with host ports and no job-level `container:`. Start Postgres as a
  step with `docker run --network "container:$HOSTNAME"` and remove it in an `if: always()` step
  (ericdahl-ops #254 is the reference). Put `ger3` in cache keys, because caches saved on
  GitHub-hosted runners don't restore here. Give test jobs `timeout-minutes`.
- The Sunday cleanup pauses each runner, so Docker shows it unhealthy for a few minutes. That's
  expected.
