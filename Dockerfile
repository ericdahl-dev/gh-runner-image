# Self-hosted GitHub Actions runner for ericdahl-dev private repos (ger3).
# Adds the system packages ubuntu-latest has that our CI relies on. Language
# runtimes (Ruby, Node, Python) are not baked in: setup-ruby/node/python
# install them per job. Add a package here once two repos need it.
FROM myoung34/github-runner:ubuntu-noble

RUN apt-get update -qq \
 && apt-get install -y --no-install-recommends wget gnupg ca-certificates \
 && wget -qO- https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
 && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
 && apt-get update -qq \
 && apt-get install -y --no-install-recommends \
      google-chrome-stable fonts-liberation \
      build-essential pkg-config libpq-dev postgresql-client libyaml-dev \
      libvips42t64 libjpeg-turbo8 libpng16-16t64 libxrender1 libxext6 libfontconfig1 \
      shellcheck \
 && rm -rf /var/lib/apt/lists/*
