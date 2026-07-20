ARG DOCKER_REGISTRY=docker.prod.nuke.benjamin-borbe.de:443
# Google's Chrome build, NOT Debian's `chromium` package: Debian's chromium 150
# build crashes at startup (SIGILL exit 132, deliberate ud2/IMMEDIATE_CRASH) in
# any container regardless of flags — the identical version from Google runs
# fine. Google's repo always ships current stable, decoupled from Debian's
# chromium build issues, and real Chrome is better for Cloudflare bypass.
FROM debian:trixie-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    ca-certificates \
    fonts-liberation \
    socat \
    && wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
    && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm /tmp/chrome.deb \
    && rm -rf /var/lib/apt/lists/*

COPY run.sh /opt/
RUN chmod +x /opt/run.sh

EXPOSE 9222

CMD ["/opt/run.sh"]
