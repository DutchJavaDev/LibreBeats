#!/bin/sh
#
# Tests for the LibreBeats layer: setup.sh, update.sh (incl. --check, --adopt,
# --nginx-snippet), reset.sh and librebeats-lib.sh.
#
# No Docker is needed. docker and ss are stubbed. The upstream release and the
# LibreBeats branch are local git repositories built from this checkout, so the
# scripts fetch the same kind of refs they fetch from GitHub.
#
# Needs on PATH: git, jq, openssl, tar, sed, awk, grep, node.
# Run: sh tests/test-librebeats.sh

set -u

DOCKER_DIR=$(cd "$(dirname "$0")/.." && pwd)

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required on PATH" >&2
    exit 1
fi

T=$(mktemp -d)
trap '[ -n "${KEEP_T:-}" ] || { chmod -R u+w "$T" 2>/dev/null; rm -rf "$T"; }' EXIT

native() { cygpath -m "$1" 2>/dev/null || printf '%s' "$1"; }

PASS=0
FAIL=0
ok()  { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

# check <label> <command...>: passes when the command exits 0.
check() {
    _label=$1
    shift
    if "$@" >/dev/null 2>&1; then ok "$_label"; else bad "$_label"; fi
}

export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

# --- stubs --------------------------------------------------------------------

STUB_DIR="$T/stub"
mkdir -p "$T/bin" "$STUB_DIR"
export STUB_DIR
PATH="$T/bin:$PATH"
export PATH

cat > "$T/bin/docker" <<'EOF'
#!/bin/sh
# Stub docker: records each call and answers what the scripts ask for.
echo "$*" >> "$STUB_DIR/docker.log"
case "$1" in
    compose)
        case "$2" in
            config)
                if [ "$3" = "-q" ]; then
                    [ -f "$STUB_DIR/config.fail" ] && exit 1
                    exit 0
                fi
                # Before adopt there is no managed layer; after it the "after" config applies.
                if [ -f .librebeats/manifest ] && [ -f "$STUB_DIR/config.after" ]; then
                    cat "$STUB_DIR/config.after"
                else
                    cat "$STUB_DIR/config.before"
                fi
                exit 0 ;;
        esac
        exit 0 ;;
    volume)
        case "$2" in
            ls) printf 'supabase_db-config\nsupabase_deno-cache\nsupabase_nginx_letsencrypt\n' ;;
        esac
        exit 0 ;;
esac
exit 0
EOF
cat > "$T/bin/ss" <<'EOF'
#!/bin/sh
cat "$STUB_DIR/ss.out" 2>/dev/null
exit 0
EOF
chmod +x "$T/bin/docker" "$T/bin/ss"

printf '%s\n' '{"services":{"db":{"image":"supabase/postgres","environment":{"POSTGRES_DB":"postgres"}}}}' > "$STUB_DIR/config.before"
: > "$STUB_DIR/ss.out"

# --- fixtures -----------------------------------------------------------------

RELEASE="$T/release"
mkdir -p "$RELEASE"
(cd "$DOCKER_DIR" && tar cf - --exclude=./tests .) | (cd "$RELEASE" && tar xf -)

UP="$T/upstream"
mkdir -p "$UP/docker"
cp -R "$RELEASE/." "$UP/docker/"
# Upstream ships the .env template; the LibreBeats layer does not.
cat > "$UP/docker/.env.example" <<'EOF'
COMPOSE_FILE=docker-compose.yml
POSTGRES_PASSWORD=your-super-secret-and-long-postgres-password
JWT_SECRET=your-super-secret-jwt-token-with-at-least-32-characters-long
ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAgICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE
SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAgICAicm9sZSI6ICJzZXJ2aWNlX3JvbGUiLAogICAgImlzcyI6ICJzdXBhYmFzZS1kZW1vIiwKICAgICJpYXQiOiAxNjQxNzY5MjAwLAogICAgImV4cCI6IDE3OTk1MzU2MDAKfQ.DaYlNEoUrrEn2Ig7tqibS-PHK5vgusbcbo7X36XVt4Q
SUPABASE_PUBLISHABLE_KEY=
SUPABASE_SECRET_KEY=
JWT_KEYS=
JWT_JWKS=
ANON_KEY_ASYMMETRIC=
SERVICE_ROLE_KEY_ASYMMETRIC=
DASHBOARD_USERNAME=supabase
DASHBOARD_PASSWORD=this_password_is_insecure_and_should_be_updated
SECRET_KEY_BASE=UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3gZv1/u2oq
SUPABASE_PUBLIC_URL=http://localhost:8000
API_EXTERNAL_URL=http://localhost:8000/auth/v1
SITE_URL=http://localhost:3000
API_GW_HTTP_PORT=8000
PROXY_DOMAIN=your-domain.example.com
CERTBOT_EMAIL=admin@example.com
PGRST_DB_SCHEMAS=public,graphql_public
PGRST_DB_MAX_ROWS=1000
PGRST_DB_EXTRA_SEARCH_PATH=public
JWT_EXPIRY=3600
EOF
(cd "$UP" && git init -q && git add -A && git commit -qm "release 0.8.1" && git tag self-hosted/v0.8.1)
echo "-- upstream 0.8.2 change" >> "$UP/docker/volumes/db/roles.sql"
echo "-- upstream 0.8.2 change" >> "$UP/docker/volumes/db/jwt.sql"
(cd "$UP" && git add -A && git commit -qm "release 0.8.2" && git tag self-hosted/v0.8.2)

LBREPO="$T/lb"
mkdir -p "$LBREPO/src/backend-self-hosted/docker"
cp -R "$RELEASE/." "$LBREPO/src/backend-self-hosted/docker/"
(cd "$LBREPO" && git init -q && git checkout -q -b librebeats && git add -A && git commit -qm "layer")
LB_DOCKER="$LBREPO/src/backend-self-hosted/docker"

COOKIE="$T/cookies.txt"
printf '# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t4102444800\tCONSENT\tYES+\n' > "$COOKIE"

UP_NATIVE=$(native "$UP")
LB_NATIVE=$(native "$LBREPO")
export SUPABASE_REPO_URL="$UP_NATIVE"
export LIBREBEATS_REPO_URL="$LB_NATIVE"

# --- helpers ------------------------------------------------------------------

setup_host() {
    (cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$1" \
        --public-url https://beats.example.com --proxy host \
        --cookies "$COOKIE" --ref self-hosted/v0.8.1) > "$T/setup.log" 2>&1
}

setup_docker() {
    (cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$1" \
        --public-url https://beats.example.com --proxy docker \
        --certbot-email ops@beats.example.org \
        --cookies "$COOKIE" --ref self-hosted/v0.8.1) > "$T/setup.log" 2>&1
}

# with_env <deployment> <KEY> <value>: replace one .env line.
with_env() {
    sed -i "s|^$2=.*|$2=$3|" "$1/.env"
}

# snapshot <dir>: checksums of everything the update must not disturb.
snapshot() {
    (cd "$1" && find . -type f ! -path './backups/*' ! -name '.librebeats-version' \
        ! -name '.supabase-version' | sort | xargs sha256sum)
}

clean_copy() { # clean_copy <dest>
    rm -rf "$1"
    cp -R "$DEP_CLEAN" "$1"
}

# --- fixtures: one clean host deployment, copied for each test -------------------

DEP_CLEAN="$T/dep-clean"
setup_host "$DEP_CLEAN"
check "setup (host mode) succeeds" test -f "$DEP_CLEAN/.librebeats-version"

echo "--- setup"
check "setup records the upstream ref" grep -qxF 'ref=self-hosted/v0.8.1' "$DEP_CLEAN/.supabase-version"
check "setup writes the public URL" grep -qxF 'SUPABASE_PUBLIC_URL=https://beats.example.com' "$DEP_CLEAN/.env"
check "host mode binds the gateway to loopback" grep -qxF 'API_GW_HTTP_PORT=127.0.0.1:8000' "$DEP_CLEAN/.env"
check "host mode keeps the nginx override out" grep -qxF 'COMPOSE_FILE=docker-compose.yml' "$DEP_CLEAN/.env"
check "PostgREST exposes the librebeats schema" grep -qxF 'PGRST_DB_SCHEMAS=public,librebeats' "$DEP_CLEAN/.env"
check "secrets were generated" sh -c "! grep -q '^JWT_SECRET=your-super-secret' '$DEP_CLEAN/.env'"
check "cookies were copied into the audio service" test -f "$DEP_CLEAN/service/audio/cookies.txt"
check "cookies are never in the manifest" sh -c "! grep -q cookies '$DEP_CLEAN/.librebeats/manifest'"
check "binaries are never in the manifest" sh -c "! grep -q '\.exe' '$DEP_CLEAN/.librebeats/manifest'"
check "the LibreBeats compose is installed" cmp -s "$DEP_CLEAN/docker-compose.yml" "$DEP_CLEAN/.librebeats/base/docker-compose.yml"
check "upstream files come from the release" test -f "$DEP_CLEAN/run.sh"
check "no key-script leftovers" sh -c "! ls '$DEP_CLEAN'/.env.old '$DEP_CLEAN'/docker-compose.yml.old >/dev/null 2>&1"
check "the stamp records the LibreBeats URL" grep -qF "librebeats_url=$LB_NATIVE" "$DEP_CLEAN/.librebeats-version"

echo "--- preflight, passing and failing"
DEP_T="$T/dep-t"
clean_copy "$DEP_T"
check "--check passes on a fresh setup" sh -c "cd '$DEP_T' && sh update.sh --check"

clean_copy "$DEP_T"; rm -f "$DEP_T/service/audio/cookies.txt"
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'cookies.txt is missing' && ok "--check fails without cookies.txt" || bad "--check fails without cookies.txt"

clean_copy "$DEP_T"; with_env "$DEP_T" JWT_SECRET your-super-secret-jwt-token-with-at-least-32-characters-long
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'JWT_SECRET is empty or still the template value' && ok "--check fails on template JWT_SECRET" || bad "--check fails on template JWT_SECRET"

clean_copy "$DEP_T"; with_env "$DEP_T" PGRST_DB_SCHEMAS public,graphql_public
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'must include librebeats' && ok "--check fails when the librebeats schema is not exposed" || bad "--check fails when the librebeats schema is not exposed"

clean_copy "$DEP_T"; with_env "$DEP_T" SUPABASE_PUBLIC_URL http://beats.example.com
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'must be an https:// URL' && ok "--check fails on a non-https public URL" || bad "--check fails on a non-https public URL"

clean_copy "$DEP_T"; with_env "$DEP_T" SUPABASE_PUBLIC_URL https://localhost:8000
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'points at localhost' && ok "--check fails on a localhost public URL" || bad "--check fails on a localhost public URL"

clean_copy "$DEP_T"; with_env "$DEP_T" API_GW_HTTP_PORT 8000
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'must bind loopback' && ok "--check fails when the gateway is exposed in host mode" || bad "--check fails when the gateway is exposed in host mode"

clean_copy "$DEP_T"; printf '<<<<<<< yours\n' >> "$DEP_T/docker-compose.yml"
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'merge conflict markers' && ok "--check fails on unresolved conflict markers" || bad "--check fails on unresolved conflict markers"

clean_copy "$DEP_T"; touch "$STUB_DIR/config.fail"
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
rm -f "$STUB_DIR/config.fail"
echo "$out" | grep -qF 'docker compose config failed' && ok "--check fails when compose config is invalid" || bad "--check fails when compose config is invalid"

clean_copy "$DEP_T"; with_env "$DEP_T" COMPOSE_FILE "docker-compose.yml:docker-compose.nginx.yml"
with_env "$DEP_T" PROXY_DOMAIN your-domain.example.com
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'PROXY_DOMAIN is empty or still the template value' && ok "--check fails on the template PROXY_DOMAIN (docker mode)" || bad "--check fails on the template PROXY_DOMAIN (docker mode)"

echo "--- setup failures"
DEP_NOCOOKIE="$T/dep-nocookie"
out=$(cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$DEP_NOCOOKIE" \
    --public-url https://beats.example.com --proxy host --ref self-hosted/v0.8.1 2>&1 || true)
echo "$out" | grep -qF 'cookies.txt is missing' && ok "setup fails without a cookies file" || bad "setup fails without a cookies file"

out=$(cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$T/dep-badurl" \
    --public-url http://beats.example.com --proxy host --cookies "$COOKIE" 2>&1 || true)
echo "$out" | grep -qF -- '--public-url must be an https' && ok "setup rejects an http public URL" || bad "setup rejects an http public URL"

out=$(cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$T/dep-noemail" \
    --public-url https://beats.example.com --proxy docker --cookies "$COOKIE" 2>&1 || true)
echo "$out" | grep -qF -- '--certbot-email is required' && ok "setup requires a certbot email in docker mode" || bad "setup requires a certbot email in docker mode"

echo "--- cookies format"
cookie_check() { ( . "$LB_DOCKER/librebeats-lib.sh"; lb_check_cookies "$1" ) >"$T/cookie.out" 2>&1; }

COOK="$T/cookie-cases"
mkdir -p "$COOK"
printf '[{"domain":".youtube.com","name":"CONSENT"}]\n' > "$COOK/json.txt"
printf 'domain,flag,path\n.youtube.com,TRUE,/\n' > "$COOK/csv.txt"
printf '# Netscape HTTP Cookie File\n' > "$COOK/header-only.txt"
printf '# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t0\tNAME\n' > "$COOK/six-fields.txt"
printf '# Netscape HTTP Cookie File\n.youtube.com\tyes\t/\tTRUE\t0\tNAME\tVAL\n' > "$COOK/bad-bool.txt"
printf '# Netscape HTTP Cookie File\n.youtube.com\tTRUE\t/\tTRUE\t1\tOLD\tVAL\n' > "$COOK/expired.txt"
printf '# Netscape HTTP Cookie File\r\n.youtube.com\tTRUE\t/\tTRUE\t4102444800\tCONSENT\tYES+\r\n' > "$COOK/crlf.txt"
printf '# Netscape HTTP Cookie File\n#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t0\tSID\tabc\n' > "$COOK/httponly.txt"

cookie_check "$COOK/crlf.txt" && ok "a CRLF Netscape file is accepted" || bad "a CRLF Netscape file is accepted"
cookie_check "$COOK/httponly.txt" && ok "an #HttpOnly_ cookie line is accepted" || bad "an #HttpOnly_ cookie line is accepted"
cookie_check "$COOKIE" && ok "the test cookie file is accepted" || bad "the test cookie file is accepted"
cookie_check "$COOK/json.txt" && bad "a JSON export is rejected" || { grep -qF 'not in Netscape cookie format' "$T/cookie.out" && ok "a JSON export is rejected" || bad "a JSON export is rejected"; }
cookie_check "$COOK/csv.txt" && bad "a CSV export is rejected" || { grep -qF 'not in Netscape cookie format' "$T/cookie.out" && ok "a CSV export is rejected" || bad "a CSV export is rejected"; }
cookie_check "$COOK/header-only.txt" && bad "a header with no cookies is rejected" || { grep -qF 'no cookies' "$T/cookie.out" && ok "a header with no cookies is rejected" || bad "a header with no cookies is rejected"; }
cookie_check "$COOK/six-fields.txt" && bad "a cookie line with 6 fields is rejected" || { grep -qF 'tab-separated fields' "$T/cookie.out" && ok "a cookie line with 6 fields is rejected" || bad "a cookie line with 6 fields is rejected"; }
cookie_check "$COOK/bad-bool.txt" && bad "a non-boolean flag is rejected" || { grep -qF 'must be TRUE or FALSE' "$T/cookie.out" && ok "a non-boolean flag is rejected" || bad "a non-boolean flag is rejected"; }
cookie_check "$COOK/missing.txt" && bad "a missing file is rejected" || ok "a missing file is rejected"

( . "$LB_DOCKER/librebeats-lib.sh"; lb_check_cookies "$COOK/expired.txt" ) >/dev/null 2>"$T/expired.err"
grep -qF 'has expired' "$T/expired.err" && ok "an all-expired file warns" || bad "an all-expired file warns"
[ -s "$T/expired.err" ] && ( . "$LB_DOCKER/librebeats-lib.sh"; lb_check_cookies "$COOK/expired.txt" ) >/dev/null 2>&1 && ok "an all-expired file is still accepted" || bad "an all-expired file is still accepted"

out=$(cd "$T" && sh "$LB_DOCKER/setup.sh" --yes --skip-deps -p "$T/dep-cookie-json" \
    --public-url https://beats.example.com --proxy host --cookies "$COOK/json.txt" 2>&1 || true)
echo "$out" | grep -qF 'cannot be used as cookies.txt' && ok "setup aborts on a non-Netscape cookies file" || bad "setup aborts on a non-Netscape cookies file"
[ ! -e "$T/dep-cookie-json" ] && ok "setup creates nothing when the cookies file is rejected" || bad "setup creates nothing when the cookies file is rejected"

DEP_CK="$T/dep-cookie-check"
clean_copy "$DEP_CK"
cp "$COOK/csv.txt" "$DEP_CK/service/audio/cookies.txt"
out=$(cd "$DEP_CK" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'not in Netscape cookie format' && ok "--check fails on a non-Netscape cookies.txt in the deployment" || bad "--check fails on a non-Netscape cookies.txt in the deployment"

echo "--- docker mode"
DEP_DOCKER="$T/dep-docker"
setup_docker "$DEP_DOCKER"
check "setup (docker mode) succeeds" test -f "$DEP_DOCKER/.librebeats-version"
check "docker mode adds the nginx override" grep -qxF 'COMPOSE_FILE=docker-compose.yml:docker-compose.nginx.yml' "$DEP_DOCKER/.env"
check "docker mode passes --check" sh -c "cd '$DEP_DOCKER' && sh update.sh --check"

clean_copy "$DEP_T"; with_env "$DEP_T" COMPOSE_FILE "docker-compose.yml:docker-compose.nginx.yml"
with_env "$DEP_T" CERTBOT_EMAIL admin@example.com
out=$(cd "$DEP_T" && sh update.sh --check 2>&1 || true)
echo "$out" | grep -qF 'must be a real mailbox' && ok "--check fails on a placeholder certbot email" || bad "--check fails on a placeholder certbot email"

printf 'LISTEN 0 511 0.0.0.0:443 0.0.0.0:* users:(("nginx",pid=1,fd=6))\n' > "$STUB_DIR/ss.out"
out=$(cd "$DEP_DOCKER" && sh update.sh --check 2>&1 || true)
: > "$STUB_DIR/ss.out"
echo "$out" | grep -qF 'ports 80 or 443 are used' && ok "--check fails when host nginx holds 443 in docker mode" || bad "--check fails when host nginx holds 443 in docker mode"

echo "--- nginx snippet"
out=$(cd "$DEP_CLEAN" && sh update.sh --nginx-snippet 2>&1)
echo "$out" | grep -qF 'server_name beats.example.com;' && ok "--nginx-snippet renders the domain" || bad "--nginx-snippet renders the domain"

echo "--- update"
DEP_U="$T/dep-u"
clean_copy "$DEP_U"
before=$(snapshot "$DEP_U")
(cd "$DEP_U" && sh update.sh --yes --to self-hosted/v0.8.1) >"$T/u1.log" 2>&1
after=$(snapshot "$DEP_U")
[ "$before" = "$after" ] && ok "update with no changes touches no file" || bad "update with no changes touches no file"

clean_copy "$DEP_U"
printf 'MY_NOTE=keep-me\n' >> "$DEP_U/.env"
printf 'services: {}\n' > "$DEP_U/docker-compose.override.yml"
mkdir -p "$DEP_U/volumes/db/data" && echo pgdata > "$DEP_U/volumes/db/data/pg.file"
(cd "$DEP_U" && sh update.sh --yes) >"$T/u2.log" 2>&1
check "upstream release change is applied" grep -qF 'upstream 0.8.2 change' "$DEP_U/volumes/db/roles.sql"
check "a LibreBeats-owned file is not overwritten by upstream" sh -c "! grep -qF 'upstream 0.8.2 change' '$DEP_U/volumes/db/jwt.sql'"
check "upstream changes to LibreBeats files are reported" grep -qF 'Supabase changed volumes/db/jwt.sql' "$T/u2.log"
check "the version stamp moves to the new release" grep -qxF 'ref=self-hosted/v0.8.2' "$DEP_U/.supabase-version"
check "user .env values survive" grep -qxF 'MY_NOTE=keep-me' "$DEP_U/.env"
check "docker-compose.override.yml survives" grep -qxF 'services: {}' "$DEP_U/docker-compose.override.yml"
check "volumes/db/data survives" test -f "$DEP_U/volumes/db/data/pg.file"
check "cookies.txt survives" cmp -s "$COOKIE" "$DEP_U/service/audio/cookies.txt"

clean_copy "$DEP_U"
printf '\n# my compose note\n' >> "$DEP_U/docker-compose.yml"
(cd "$DEP_U" && sh update.sh --yes --to self-hosted/v0.8.1) >"$T/u4.log" 2>&1
check "a LibreBeats file edited by the user is kept" grep -qF '# my compose note' "$DEP_U/docker-compose.yml"

echo "--- LibreBeats layer changes"
echo "// lb change 2" >> "$LBREPO/src/backend-self-hosted/docker/service/audio/storage.go"
(cd "$LBREPO" && git add -A && git commit -qm "lb change 2")
clean_copy "$DEP_U"
(cd "$DEP_U" && sh update.sh --yes --to self-hosted/v0.8.1) >"$T/u3.log" 2>&1
check "a LibreBeats change reaches the deployment" grep -qF '// lb change 2' "$DEP_U/service/audio/storage.go"
check "the LibreBeats base copy moves with it" grep -qF '// lb change 2' "$DEP_U/.librebeats/base/service/audio/storage.go"
check "the stamp records the new LibreBeats commit" grep -qF "librebeats_commit=$(cd "$LBREPO" && git rev-parse HEAD)" "$DEP_U/.librebeats-version"

echo "// lb change 3" >> "$LBREPO/src/backend-self-hosted/docker/service/audio/storage.go"
(cd "$LBREPO" && git add -A && git commit -qm "lb change 3")
clean_copy "$DEP_U"
echo "// user edit" >> "$DEP_U/service/audio/storage.go"
stamp_before=$(grep -F 'librebeats_commit=' "$DEP_U/.librebeats-version")
(cd "$DEP_U" && sh update.sh --yes --to self-hosted/v0.8.1) >"$T/u5.log" 2>&1
rc=$?
check "a conflict exits 2" test "$rc" -eq 2
check "a conflict leaves markers in the file" grep -qF '<<<<<<<' "$DEP_U/service/audio/storage.go"
check "a conflict does not move the version stamp" grep -qxF "$stamp_before" "$DEP_U/.librebeats-version"

echo "--- upstream unreachable"
clean_copy "$DEP_U"
out=$(cd "$DEP_U" && SUPABASE_REPO_URL="$T/does-not-exist" sh update.sh --yes 2>&1 || true)
echo "$out" | grep -qF 'Could not reach' && ok "update refuses to fall back to master when upstream is unreachable" || bad "update refuses to fall back to master when upstream is unreachable"

echo "--- adopt"
DEP_A="$T/dep-adopt"
clean_copy "$DEP_A"
rm -rf "$DEP_A/.librebeats" "$DEP_A/.librebeats-version"
(cd "$DEP_A" && sh update.sh --adopt --librebeats-url "$LB_NATIVE") >"$T/adopt.log" 2>&1
check "adopt converts a setup.sh deployment" test -f "$DEP_A/.librebeats-version"
check "adopt writes the manifest" test -f "$DEP_A/.librebeats/manifest"
check "adopt keeps the upstream release" grep -qxF 'ref=self-hosted/v0.8.1' "$DEP_A/.supabase-version"

DEP_A2="$T/dep-adopt-fail"
clean_copy "$DEP_A2"
rm -rf "$DEP_A2/.librebeats" "$DEP_A2/.librebeats-version"
printf '{"services":{"db":{"image":"something-else"}}}\n' > "$STUB_DIR/config.after"
(cd "$DEP_A2" && sh update.sh --adopt --librebeats-url "$LB_NATIVE") >"$T/adopt2.log" 2>&1
rc=$?
rm -f "$STUB_DIR/config.after"
check "adopt exits non-zero when the compose structure would change" test "$rc" -ne 0
check "adopt rolls back the layer on a structural change" sh -c "[ ! -f '$DEP_A2/.librebeats-version' ] && [ ! -d '$DEP_A2/.librebeats' ]"
check "adopt says it rolled back" grep -qF 'rolled back' "$T/adopt2.log"

echo "--- reset"
DEP_R="$T/dep-reset"
clean_copy "$DEP_R"
jwt_before=$(grep '^JWT_SECRET=' "$DEP_R/.env")
url_before=$(grep '^SUPABASE_PUBLIC_URL=' "$DEP_R/.env")
printf 'services: {}\n' > "$DEP_R/docker-compose.override.yml"
mkdir -p "$DEP_R/volumes/db/data" && echo pgdata > "$DEP_R/volumes/db/data/pg.file"
echo "// hand edit" >> "$DEP_R/service/audio/storage.go"
echo "# hand edit" >> "$DEP_R/docker-compose.yml"
: > "$STUB_DIR/docker.log"
(cd "$DEP_R" && sh reset.sh --yes) >"$T/reset.log" 2>&1
rc=$?
check "reset exits 0" test "$rc" -eq 0
check "reset generates new secrets" sh -c "[ \"\$(grep '^JWT_SECRET=' '$DEP_R/.env')\" != '$jwt_before' ]"
check "reset keeps the public URL" grep -qxF "$url_before" "$DEP_R/.env"
check "reset keeps the proxy mode" grep -qxF 'COMPOSE_FILE=docker-compose.yml' "$DEP_R/.env"
check "reset keeps the librebeats schema exposure" grep -qxF 'PGRST_DB_SCHEMAS=public,librebeats' "$DEP_R/.env"
check "reset removes the user override" sh -c "[ ! -f '$DEP_R/docker-compose.override.yml' ]"
check "reset wipes the database directory through a container" grep -qF '/v/db/data' "$STUB_DIR/docker.log"
check "reset restores LibreBeats files from the base copy" cmp -s "$DEP_R/service/audio/storage.go" "$DEP_R/.librebeats/base/service/audio/storage.go"
check "reset restores the compose file" cmp -s "$DEP_R/docker-compose.yml" "$DEP_R/.librebeats/base/docker-compose.yml"
check "reset keeps cookies.txt" cmp -s "$COOKIE" "$DEP_R/service/audio/cookies.txt"
check "reset keeps the upstream release" grep -qxF 'ref=self-hosted/v0.8.1' "$DEP_R/.supabase-version"
check "reset archives the deployment before deleting" sh -c "tar -tzf '$DEP_R'/backups/reset-*.tgz | grep -qF 'docker-compose.override.yml'"
check "reset removes the database volume" grep -qF 'volume rm supabase_db-config' "$STUB_DIR/docker.log"
check "reset keeps the certificate volume by default" sh -c "! grep -qF 'volume rm supabase_nginx_letsencrypt' '$STUB_DIR/docker.log'"
check "reset passes the preflight" grep -qF 'preflight: ok' "$T/reset.log"

DEP_RD="$T/dep-reset-docker"
setup_docker "$DEP_RD"
: > "$STUB_DIR/docker.log"
(cd "$DEP_RD" && sh reset.sh --yes) >"$T/reset-d.log" 2>&1
check "docker mode reset keeps the certificate volume" sh -c "! grep -qF 'volume rm supabase_nginx_letsencrypt' '$STUB_DIR/docker.log'"
: > "$STUB_DIR/docker.log"
(cd "$DEP_RD" && sh reset.sh --yes --purge-certs) >"$T/reset-p.log" 2>&1
check "--purge-certs removes the certificate volume" grep -qF 'volume rm supabase_nginx_letsencrypt' "$STUB_DIR/docker.log"

echo ""
echo "passed: $PASS  failed: $FAIL"
[ "$FAIL" -eq 0 ]
