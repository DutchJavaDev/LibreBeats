# Hosting behind an existing nginx reverse proxy

This is the setup for a VPS that already has a domain, TLS via Let's Encrypt, and
nginx running directly on the host (not inside a container). Instead of the
Docker-based proxies the repo ships, the stack is exposed on loopback and the
existing nginx forwards public traffic to it.

## Why not the bundled proxy overrides

`docker-compose.nginx.yml` and `docker-compose.caddy.yml` run the proxy inside
Docker and bind ports 80/443 themselves. With nginx already on the host, those
overrides would fight over the ports and terminate TLS a second time. For this
scenario only the base `docker-compose.yml` runs.

## What listens where

- `api-gw` (Envoy by default) is the single entry point. It already routes
  `/auth/v1`, `/rest/v1`, `/storage/v1`, `/realtime/v1`, `/functions/v1`,
  `/graphql/v1` and `/` (Studio), so nginx only has to forward to it.
- `supavisor` exposes Postgres on `5432` (session) and `6543` (transaction).
- The base compose binds `8000`, `5432` and `6543` and never touches 80/443, so
  there is no conflict with the host nginx.

## 1. Public URLs in `.env`

In the project directory created by `setup.sh`, point every public URL at the
real HTTPS domain:

```ini
SUPABASE_PUBLIC_URL=https://beats.example.com
API_EXTERNAL_URL=https://beats.example.com/auth/v1
SITE_URL=https://beats.example.com
```

`SUPABASE_PUBLIC_URL` is what Storage, imgproxy, Auth and Studio use to build
absolute URLs, and what the audio worker writes into the catalog's
streaming/thumbnail URLs — so it must be the externally reachable domain, not
`localhost:8000`.

Also change `DASHBOARD_PASSWORD` (and `DASHBOARD_USERNAME` if you like); these
guard the Studio dashboard with basic auth at the gateway.

`PROXY_DOMAIN` and `CERTBOT_EMAIL` are only read by the Docker proxies, so leave
them alone here.

## 2. Keep the gateway off the public internet

By default the gateway binds `8000` on all interfaces. Since nginx runs on the
same host, bind it to loopback in `.env`:

```ini
API_GW_HTTP_PORT=127.0.0.1:8000
```

Docker Compose accepts `ip:port` in a port mapping, so this binds only on
localhost. If you also want `psql` from the host, do the same for
`POSTGRES_PORT=127.0.0.1:5432` and `POOLER_PROXY_PORT_TRANSACTION=127.0.0.1:6543`;
otherwise make sure the firewall blocks those three ports externally.

## 3. Start

```sh
sh run.sh start
```

Run the base file only — do not `sh run.sh config add nginx` or `add caddy`.

## 4. nginx

Merge the following into the existing `server { }` block that already has
`listen 443 ssl`, `server_name` and the Let's Encrypt certificate paths:

```nginx
upstream librebeats_gw {
    server 127.0.0.1:8000;
    keepalive 2;
}

server {
    # keep your existing listen 443 ssl / server_name / ssl_certificate lines

    proxy_http_version 1.1;
    proxy_set_header Host              $host;
    proxy_set_header X-Real-IP         $remote_addr;
    proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host  $http_host;
    proxy_set_header X-Forwarded-Port  $server_port;

    # Supabase auth cookies get large
    large_client_header_buffers 4 16k;
    proxy_buffer_size 128k;
    proxy_buffers 4 256k;
    proxy_busy_buffers_size 256k;

    # Realtime websocket
    location /realtime/v1/ {
        proxy_pass http://librebeats_gw;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 3600s;
    }

    # Storage: stream without buffering, no upload size cap
    location /storage/v1/ {
        proxy_pass http://librebeats_gw;
        proxy_buffering off;
        proxy_request_buffering off;
        client_max_body_size 0;
    }

    # Everything else (auth, rest, functions, graphql, Studio)
    location / {
        proxy_pass http://librebeats_gw;
    }
}
```

The Studio dashboard is already basic-auth protected by the gateway
(`DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`); the API paths use JWT/apikey auth
and are left open. To gate the dashboard at nginx instead, add your own
`auth_basic` to the `location /` block.

## 5. Point the app at it

The Flutter app connects like any hosted Supabase project: a base URL plus a
publishable key.

- `LIBREBEATS_SEED_URLS=https://beats.example.com`
- `LIBREBEATS_SEED_KEYS=<SUPABASE_PUBLISHABLE_KEY>` — read it with `sh run.sh secrets`

Sign-in is for existing accounts only. Use the seeded listener account
(`listner@librebeats.com`); see the note below about its password.

## Gotchas

- **WebSocket**: Realtime needs the `Upgrade`/`Connection` headers and the long
  `proxy_read_timeout` in the `/realtime/v1/` block, or subscriptions hang.
- **Streaming URLs**: the audio worker stores public object URLs ending in
  `?download=true` (legacy behavior). That sets `Content-Disposition: attachment`,
  which is fine for artwork but can break audio streaming in some players. If
  playback misbehaves, drop `?download=true` in `service/audio/storage.go`.
- **Large uploads**: keep `client_max_body_size 0` and the buffering overrides on
  `/storage/v1/`.
- **Seeded password**: the listener user's password is hardcoded in plaintext in
  `service/migration/scripts/3 seed_libre_user.sql`. Change it in the database
  (and that file) before exposing the server.
- **Firewall**: only 80/443 need to be open publicly; `8000`, `5432` and `6543`
  should be loopback-only or blocked.
