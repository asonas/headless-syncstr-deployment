# Headless Syncstr deployment

Deploy the standalone Rust node from [Syncstr](https://github.com/asonas/syncstr/tree/1f4c815ca200f0943bbd76c884fa0f518666ec40/headless). The Compose build uses the upstream Dockerfile at a fixed commit. Change the commit in `docker-compose.yml` to upgrade; application source and dependency notices remain maintained upstream.

## Coolify

Create a Git-based Docker Compose application with branch `main`, Base Directory `/`, and Compose Location `/docker-compose.yml`. Use the NAS server. Configure the variables from `.env.example` with the NAS's actual LAN address. The example address is fictional. Do not assign a proxy domain: this service handles TLS on port 8443 itself.

Create the two host directories listed under `volumes` in `docker-compose.yml` before deployment, owned by the configured numeric UID/GID with mode 0700. Keep them outside Coolify's repository checkout. Edit the Compose paths when using a different storage layout. Absolute bind mounts avoid host-path interpolation and external-volume rewriting in older Coolify parsers.

Do not reuse an app's SQLite database or an existing music directory. The service stores uploaded originals in its own object store; it does not scan existing music.

Before the first deployment, build the image and initialize its identity once:

```sh
cp .env.example .env
# Edit .env for this host before continuing.
docker compose build
docker compose run --rm --no-deps \
  --volume "$SYNCSTR_IDENTITY_DIRECTORY:/identity:rw" \
  syncstr init --identity /identity --host 192.0.2.10
docker compose up -d
```

Set `SYNCSTR_IDENTITY_DIRECTORY` to the absolute identity bind source in the Compose file before running initialization. Replace the example address with the address used by clients. If Coolify builds first, the first launch will fail until initialization is completed; run `init` using that built image and restart this application. Initialization never overwrites an existing identity. The node certificate expires after one year.

The container runs without root or extra capabilities, with a read-only root filesystem, writable `/data`, and read-only `/identity`. Verify these settings in the actual container after deployment. The LAN binding does not configure router forwarding, a relay, or external connectivity.

## Client verification

Transfer only `tls.crt` and `token` to an authorized client through a trusted channel; keep `tls.key` on the NAS. The current token grants all node operations. Never commit identity files or tokens.

Using the upstream CLI:

```sh
syncstr-headless catalog --url https://192.0.2.10:8443 \
  --cert ./tls.crt --token-file ./token
```

Verify an upload, retry, restart, and byte-identical download before using the node for originals. Native macOS/iPhone NAS registration, automatic collection, Bonjour discovery, and P2P enrollment are not implemented in this milestone.

Stop the application before backing up both persistent directories. Redeployments must retain the same mounts. Do not run two node processes against the same data directory.
