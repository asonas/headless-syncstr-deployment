# Headless Syncstr deployment

Deploy the standalone Rust node from [Syncstr](https://github.com/asonas/syncstr/tree/565e1ad2064ab57438e595a6978ca236a0819eae/headless). The Compose build enables P2P using the upstream Dockerfile at a fixed commit. Change the commit in `docker-compose.yml` to upgrade; application source and dependency notices remain maintained upstream.

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

The container runs without root or extra capabilities, with a read-only root filesystem, writable `/data`, and read-only `/identity`. Verify these settings in the actual container after deployment. Linux host networking exposes the node's UDP addresses directly and binds HTTPS only to the configured NAS address and port. There are no Compose port mappings. Host networking shares the host's network namespace; use the NAS firewall to restrict access. It does not configure router forwarding or external connectivity.

## P2P enrollment

Startup initializes `/data/peer` once and retains its private key and allowed-device records across deployments. An existing but incomplete directory causes startup to fail rather than replacing an identity. Keep the entire data directory in backups. Direct mode disables relay services; remote access requires a reachable UDP route.

Read the current public node address record:

```sh
docker compose exec syncstr syncstr-headless peer-info \
  --state /data/peer --address /data/peer/address.json --ip 192.0.2.10
```

In the native app's P2P music sharing settings, copy the app's public device ID. Allow that device on the NAS:

```sh
docker compose exec syncstr syncstr-headless peer-pair \
  --state /data/peer --peer <device-public-id>
```

Replace the fictional IP with the NAS's reachable LAN IP. Paste the exported JSON into the app, then confirm the displayed node ID before registration. Add `--qr` to display a QR code for the iPhone scanner. The UDP port can change when the node restarts, so export again after a restart. Do not share `device.key`. To revoke access, repeat the pairing command with `--revoke`. For Coolify-managed containers, use its terminal or `docker exec` against the running container instead of starting a second node.

## Client verification

Transfer only `tls.crt` and `token` to an authorized client through a trusted channel; keep `tls.key` on the NAS. The current token grants all node operations. Never commit identity files or tokens.

Using the upstream CLI:

```sh
syncstr-headless catalog --url https://192.0.2.10:8443 \
  --cert ./tls.crt --token-file ./token
```

Verify an upload, retry, restart, and byte-identical download before using the node for originals. Native macOS/iPhone apps support explicit P2P registration and transfers. Automatic collection and remote-network connectivity still require separate work and verification.

Stop the application before backing up both persistent directories. Redeployments must retain the same mounts. Do not run two node processes against the same data directory.
