# chromium-browser

Headless **Google Chrome** in a container, exposing a Chrome DevTools Protocol
endpoint on `:9222` (via a `socat` fork proxy). Uses Google's Chrome build, not
Debian's `chromium` package — Debian's build SIGILLs (exit 132) at startup in a
container regardless of flags; the identical Google build runs fine and is better
for Cloudflare bypass.

Generic scraping infra (extracted from the trading monorepo). Publish-only:
`docker.io/bborbe/chromium-browser:vX.Y.Z`.

## Usage

```bash
docker run -ti -p 9222:9222 bborbe/chromium-browser:latest
# CDP endpoint: http://localhost:9222
```
