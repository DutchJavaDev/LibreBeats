# Host nginx server block for scenario A (nginx on the host, TLS by certbot).
# Rendered with the domain filled in by: sh update.sh --nginx-snippet
# Merge it into your existing nginx configuration and reload nginx.

upstream librebeats_gw {
    server 127.0.0.1:8000;
    keepalive 2;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name ${DOMAIN};

    ssl_certificate     /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;

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

    # Everything else (auth, rest, functions, graphql, Studio). Studio is
    # protected by the gateway's basic auth (DASHBOARD_USERNAME / DASHBOARD_PASSWORD).
    location / {
        proxy_pass http://librebeats_gw;
    }
}
