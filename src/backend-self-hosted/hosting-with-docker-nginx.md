# Hosting with the bundled nginx container (scenario B)

For a server where nothing else uses ports 80 and 443. The stack includes an
nginx container with certbot (`docker-compose.nginx.yml`), which terminates TLS
and gets the Let's Encrypt certificate itself. Use scenario A
(`hosting-with-existing-nginx.md`) if nginx already runs on the host.

## Before you start

- A DNS record for your domain points at this server.
- Ports 80 and 443 are open in the firewall and not used by anything else.
  Stop host nginx if it is running, or use scenario A.

## 1. Install

```sh
cd LibreBeats/src/backend-self-hosted/docker
sh setup.sh --public-url https://beats.example.com --proxy docker \
    --proxy-domain beats.example.com --certbot-email you@example.com \
    --cookies ~/yt-dlp-cookies.txt
```

- `--certbot-email` is where Let's Encrypt sends expiry notices. Use a mailbox
  you read. `@example.com` addresses are rejected.
- `--cookies` must be a Netscape-format cookies file (first line
  `# Netscape HTTP Cookie File`). Setup aborts on JSON or CSV exports.
- Setup adds `docker-compose.nginx.yml` to `COMPOSE_FILE`, so `run.sh` and the
  update and reset commands include it automatically.
- The preflight checks that ports 80 and 443 are free or held by Docker, and
  warns if the domain does not resolve to this server yet.

## 2. Start

```sh
cd supabase-project
sh update.sh --check       # must print "preflight: ok (docker proxy)"
sh run.sh start
```

The first start asks Let's Encrypt for the certificate. Follow it with:

```sh
sh run.sh logs nginx
```

## 3. Check it works

```sh
curl -fsS https://beats.example.com/auth/v1/health
```

Studio is at `https://beats.example.com/` and asks for `DASHBOARD_USERNAME` and
`DASHBOARD_PASSWORD` from `.env`. The nginx container applies that basic auth
itself.

## 4. Connect the app

```sh
sh run.sh secrets        # prints the publishable key; do not paste the output anywhere
```

Use the public URL and the publishable key in the Flutter app's seed settings,
as described in `hosting-with-existing-nginx.md`, section 5.

## 5. Updates

```sh
cd supabase-project
sh update.sh --check
sh update.sh --dry-run
sh update.sh
sh run.sh recreate nginx   # if the proxy files changed
sh run.sh recreate
```

- The nginx template and override come from upstream Supabase, so the update
  merges them like any other upstream file.
- Commit and push LibreBeats changes to the `librebeats` branch before updating.

## 6. Reset

```sh
cd supabase-project
sh reset.sh
```

Reset keeps the Let's Encrypt volume (`supabase_nginx_letsencrypt`) by default.
Let's Encrypt allows only five certificates per exact domain per week, and
deleting the volume on every reset can use them up quickly. To delete it too,
run `sh reset.sh --purge-certs`.

## Notes

- Only ports 80 and 443 need to be public. The gateway, Postgres and the pooler
  stay on the Docker network and are not published by this scenario.
- Certificate renewal runs inside the nginx container. If renewal fails, check
  `sh run.sh logs nginx` and confirm port 80 still reaches this server.
- Public object URLs end in `?download=true`, which tells the browser to save
  the file. That is fine for artwork. If audio playback misbehaves, drop that
  query in `service/audio/storage.go`.
