#!/bin/bash

set -ex

echo "my run.sh"

exec socat TCP4-LISTEN:9222,fork TCP4:127.0.0.1:9223 &

exec google-chrome \
--disable-dev-shm-usage \
--disable-gpu \
--disable-software-rasterizer \
--headless=new \
--no-sandbox \
--no-zygote \
--remote-debugging-port=9223 \
--disable-blink-features=AutomationControlled \
--disable-background-networking \
--disable-component-update \
--disable-default-apps \
--disable-sync \
--disable-features=GcmRegistration,UpdaterService,Translate \
--no-first-run \
--user-agent="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"
