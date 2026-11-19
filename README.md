# Headless Syncstr deployment

Deploy the standalone Rust node from [Syncstr](https://github.com/asonas/syncstr/tree/b652fa4fa7ee220f0f65e659394f69226a42f3ec/headless) behind a Tailscale sidecar, as [ADR 0008](https://github.com/asonas/syncstr/blob/b652fa4fa7ee220f0f65e659394f69226a42f3ec/docs/adr/0008-one-primary-host-over-a-private-network.md) describes. The Compose build uses application source at a fixed commit. Its inline Dockerfile temporarily overrides the upstream recipe to pin `webpki-roots` to 1.0.10 and remove the affected emSign G3 and AAA cross-sign trust paths from the OS store (Mozilla incident 2083449). It builds with the `p2p` feature, which the read API needs to serve playlists, and keeps the upstream dependency notices. This requires Compose with `dockerfile_inline` support. Restore the upstream Dockerfile after the pinned source includes both fixes; do not remove this override based only on an application version bump.

## How it runs

- The `tailscale` sidecar joins the tailnet in userspace and keeps its identity in the NAS state directory. Its Serve configuration publishes HTTPS on port 443 of its tailnet name and proxies every path to `http://127.0.0.1:8441`.
- The `syncstr` container shares the sidecar's network namespace. It serves the token-free read API `/api/v1` on `127.0.0.1:8441` and the legacy `/v4` API on `127.0.0.1:8443`. Both listen only on loopback inside that namespace, so Tailscale Serve is the only way in, and only to `/api/v1`. Nothing listens on the NAS's LAN address.
- The tailnet policy is the only control over who reads the library. Every device that the effective policy lets reach the sidecar's TCP port 443 reads the whole library. Check the policy before deploying.
- The legacy LAN listener, P2P transfer and rendezvous announcements are gone. Clients that used them stop working until they move to `/api/v1`.

## Coolify

Create a Git-based Docker Compose application with branch `main`, Base Directory `/`, and Compose Location `/docker-compose.yml`. Use the NAS server. Do not assign a proxy domain.

Set `SYNCSTR_API_ADDRESS` to the sidecar's tailnet HTTPS origin, such as `https://music.example.ts.net`; the example is fictional. The node reports it to devices in library information and refuses to start without it. Set `SYNCSTR_UID` and `SYNCSTR_GID` if the data directories are not owned by 1000.

Create the host directories listed under `volumes` in `docker-compose.yml` before the first deployment, owned by the configured numeric UID/GID with mode 0700, and keep them outside Coolify's repository checkout. Absolute bind mounts avoid host-path interpolation and external-volume rewriting in older Coolify parsers. Only one running daemon may use the Tailscale state directory.

Do not reuse an app's SQLite database or an existing music directory. The node stores uploaded originals in its own object store; it does not scan existing music. Do not run two node processes against the same data directory.

## First deployment

The node still needs an identity for its loopback `/v4` listener. Initialize it once before the first start:

```sh
cp .env.example .env
# Edit .env for this host before continuing.
docker compose build
docker compose run --rm --no-deps \
  --volume "$SYNCSTR_IDENTITY_DIRECTORY:/identity:rw" \
  syncstr init --identity /identity --host 127.0.0.1
```

Set `SYNCSTR_IDENTITY_DIRECTORY` to the absolute identity bind source in the Compose file. Initialization never overwrites an existing identity, so an existing deployment keeps its identity. If Coolify builds first, the first launch fails until initialization is done; run `init` with the built image and restart the application.

The container runs without root or extra capabilities, with a read-only root filesystem, writable `/data`, and read-only `/identity`. Verify these settings in the running container after deployment.

## Verification

From a device the tailnet policy allows, request `https://<tailnet name>/api/v1/library` and expect 200 with this library's id, then `/api/v1/catalog`. A request with any method other than `GET` answers 405, and an unknown path answers 404. `/v4` is not reachable from the tailnet. From the NAS's LAN, nothing answers on the old Syncstr ports.

Stop the application before backing up the persistent directories. Redeployments must keep the same mounts.
