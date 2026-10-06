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
