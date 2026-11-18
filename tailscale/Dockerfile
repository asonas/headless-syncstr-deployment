FROM caddy:2-alpine@sha256:003a97808e781aa9f7e75cc2f43d34d461099031faf5e20faefb9f61126836f0 AS proxy
FROM tailscale/tailscale@sha256:72c1e19e0aedca96b8533bbb0b4368564410ff20b17e53b804eb6c1f04a31be4
COPY --from=proxy /usr/bin/caddy /usr/local/bin/caddy
COPY Caddyfile serve.json /etc/syncstr/
COPY start.sh /usr/local/bin/start-sidecar
ENTRYPOINT ["/bin/sh", "/usr/local/bin/start-sidecar"]
