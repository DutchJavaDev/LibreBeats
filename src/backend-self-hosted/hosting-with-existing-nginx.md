# Hosting behind an existing nginx (scenario A)

For a server where nginx already runs on the host with a domain and a Let's
Encrypt certificate. LibreBeats runs in Docker, bound to loopback, and your
nginx forwards public traffic to it. The bundled `docker-compose.nginx.yml`
(scenario B, see `hosting-with-docker-nginx.md`) is not used here.

## 1. Install

On the server, clone the repository on the `librebeats` branch, then run the
installer from the checkout:

```sh
cd LibreBeats/src/backend-self-hosted/docker
sh setup.sh --public-url https://beats.example.com --proxy host \
    --proxy-domain beats.example.com --cookies ~/yt-dlp-cookies.txt
```

- `--public-url` is the HTTPS address your nginx serves. It must not be
  `localhost`.
- `--cookies` is a yt-dlp cookies file exported from your browser in Netscape
  format (the first line is `# Netscape HTTP Cookie File`). Setup aborts on any
  other format. The file is git-ignored and is copied to
  `service/audio/cookies.txt` inside the deployment.
- Setup creates `supabase-project/`, installs Docker on Debian, Ubuntu, RHEL or
  Fedora if it is missing, generates the secrets and API keys, binds the API
  gateway to `127.0.0.1:8000`, and runs the preflight. The preflight lists what
  is still missing. Fix those items, then run `sh update.sh --check`.

Use `--skip-deps` if Docker is already installed.

## 2. Add the server block to nginx

From the deployment directory, print the block with your domain filled in:

```sh
cd supabase-project
sh update.sh --nginx-snippet
```

Add it to your nginx configuration for that domain. You only need the
`upstream` and `location` parts. Keep your existing `listen` and certificate
lines. Then test and reload:

```sh
sudo nginx -t && sudo systemctl reload nginx
```

Your certificates stay where they are, in `/etc/letsencrypt`. LibreBeats never
touches them in this scenario.

## 3. Start the stack

```sh
sh update.sh --check     # must print "preflight: ok (host proxy)"
sh run.sh start
```

`run.sh start` is the upstream Supabase command. It does not run the preflight
itself, so run `--check` first.

## 4. Check it works

```sh
curl -fsS https://beats.example.com/auth/v1/health
```

The answer is JSON. Then open `https://beats.example.com/` in a browser. Studio
asks for `DASHBOARD_USERNAME` and `DASHBOARD_PASSWORD` from `.env`.

## 5. Connect the app

```sh
sh run.sh secrets        # prints the publishable key; do not paste the output anywhere
```

Build or run the Flutter app with the public URL and the publishable key:

```
LIBREBEATS_SEED_URLS=https://beats.example.com
LIBREBEATS_SEED_KEYS=<SUPABASE_PUBLISHABLE_KEY>
```

There is no registration, so sign-in uses an existing account. The migration
seeds `listner@librebeats.com`. Its password is written in plaintext in
`service/migration/scripts/3 seed_libre_user.sql`, so change it in the database
and in that file before the server is reachable from the internet.

## 6. Updates

```sh
cd supabase-project
sh update.sh --check
sh update.sh --dry-run   # shows what would change
sh update.sh             # applies it, and stops on conflicts with exit code 2
sh run.sh recreate
```

- The update reads the `librebeats` branch of the repository. Commit and push
  your LibreBeats changes first, or the update will not see them.
- If the server block changed, the update prints a warning. Run
  `sh update.sh --nginx-snippet`, apply it, and reload nginx.
- Conflicts leave markers in the file. Resolve them, then run
  `sh update.sh --check` before starting the stack.

## 7. Reset

```sh
cd supabase-project
sh reset.sh
```

This archives the deployment to `backups/`, then deletes the database, storage,
SQL snippets and secrets, and rebuilds the deployment from the recorded release
and LibreBeats version. Your nginx configuration and `/etc/letsencrypt` are not
touched. Start the stack again with `sh run.sh start`.

## Existing deployment without the install record

A deployment made by the earlier `setup.sh` has no `.librebeats-version`. Adopt
it once:

```sh
cd supabase-project
sh update.sh --adopt --dry-run   # lists the files that would be replaced
sh update.sh --adopt
```

Adopt backs up the deployment first. It compares the compose structure before
and after, and rolls back if it changed. Environment changes are printed for
you to review.

## Notes

- Only ports 80 and 443 need to be public. The gateway on `127.0.0.1:8000`,
  Postgres on `5432` and the pooler on `6543` should not be reachable from the
  internet.
- `.env` holds every secret. `backups/` archives are created with mode 600, but
  keep them off shared storage anyway.
- Public object URLs end in `?download=true`, which tells the browser to save
  the file. That is fine for artwork. If audio playback misbehaves through the
  proxy, drop that query in `service/audio/storage.go`.
- The Studio dashboard is protected by the gateway's basic auth, and the API
  paths use JWT or API keys, so the server block does not add its own
  `auth_basic`.
