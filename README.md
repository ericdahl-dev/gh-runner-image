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
