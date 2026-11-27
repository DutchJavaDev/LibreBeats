#!/bin/sh
#
# Shared LibreBeats layer for setup.sh, update.sh and reset.sh. Sourced, never
# executed. Paths are relative to the deployment directory.
#
# Ownership:
#   - Upstream: everything under docker/ that is not listed in LB_PATHS.
#     Written by upstream's release, merged by update.sh.
#   - LibreBeats: the paths in LB_PATHS, including files that replace an
#     upstream file (docker-compose.yml, volumes/db/jwt.sql, ...). Recorded in
#     .librebeats/manifest, base copies in .librebeats/base/, synced from the
#     LibreBeats branch by update.sh.
#   - User: .env, docker-compose.override.yml, service/audio/cookies.txt, the
#     data directories and backups/. Never written by the layer.

LB_STAMP=".librebeats-version"
LB_MANIFEST_FILE=".librebeats/manifest"
LB_BASE_DIR=".librebeats/base"
LB_DEFAULT_REPO_URL="https://github.com/DutchJavaDev/LibreBeats.git"
LB_DEFAULT_REF="librebeats"
LB_SUBPATH="src/backend-self-hosted/docker"

LB_PATHS="
librebeats-lib.sh
update.sh
reset.sh
librebeats
docker-compose.yml
CONFIG.md
volumes/db/jwt.sql
volumes/db/librebeats-worker.sql
volumes/functions/menu
volumes/proxy/caddy/Caddyfile
volumes/proxy/nginx/supabase-nginx.conf.tpl
service
"

# .env keys that describe this deployment. reset.sh carries them over.
LB_ENV_CARRY="SUPABASE_PUBLIC_URL API_EXTERNAL_URL SITE_URL PROXY_DOMAIN CERTBOT_EMAIL COMPOSE_FILE API_GW_HTTP_PORT DASHBOARD_USERNAME"

# Set by the script that sources this file, so it can defer replacing itself.
LB_SELF="${LB_SELF:-}"
LB_DEFERRED_LIST=""

lb_log()  { printf '===> %s\n' "$*"; }
lb_warn() { printf 'WARNING: %s\n' "$*" >&2; }
lb_die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

env_get_file() { grep -E "^$2=" "$1" 2>/dev/null | tail -n1 | cut -d= -f2- | tr -d '\r'; }
env_get()      { env_get_file .env "$1"; }

# env_set KEY VALUE - replace the last-defined KEY= line in .env, or append it.
# Values go through ENVIRON, so characters like & | \ are written literally.
env_set() {
    K="$1" V="$2" awk 'BEGIN { k = ENVIRON["K"]; v = ENVIRON["V"]; done = 0 }
        index($0, k "=") == 1 { print k "=" v; done = 1; next }
        { print }
        END { if (!done) print k "=" v }' .env > .env.lbtmp && mv -f .env.lbtmp .env
}

lb_stamp_get() { grep -E "^$1=" "$LB_STAMP" 2>/dev/null | head -n1 | cut -d= -f2-; }

# lb_write_stamps <upstream-ref> <librebeats-url> <librebeats-ref> <commit> <nginx-sha>
lb_write_stamps() {
    {
        echo "# Supabase self-hosted version stamp. Managed by setup.sh / update.sh / reset.sh."
        echo "# Do not commit or edit by hand. Records the ref this deployment was based on."
        echo "ref=$1"
    } > .supabase-version
    {
        echo "# LibreBeats install record. Managed by setup.sh / update.sh / reset.sh."
        echo "librebeats_url=$2"
        echo "librebeats_ref=$3"
        echo "librebeats_commit=$4"
        echo "nginx_sha256=$5"
        echo "installed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$LB_STAMP"
}

# lb_mode - "docker" when the bundled nginx override is active, else "host".
lb_mode() {
    case ":$(env_get COMPOSE_FILE):" in
        *:docker-compose.nginx.yml:*) echo docker ;;
        *) echo host ;;
    esac
}

# lb_expand <dir> - LibreBeats-owned files that exist in <dir>, one per line.
# cookies.txt and Windows binaries never ship with the layer.
lb_expand() {
    for _p in $LB_PATHS; do
        if [ -d "$1/$_p" ]; then
            ( cd "$1" && find "$_p" -type f )
        elif [ -f "$1/$_p" ]; then
            printf '%s\n' "$_p"
        fi
    done | grep -vE '(^|/)cookies\.txt$|\.exe$' | sort -u
}

# lb_fetch <url> <ref> <subpath> <dest> - sparse, shallow copy of one directory.
# Sets LB_FETCHED_COMMIT. Works for branches, tags and commit SHAs.
lb_fetch() {
    _work=$(mktemp -d) || return 1
    if git init -q "$_work/repo" \
        && git -C "$_work/repo" remote add origin "$1" \
        && git -C "$_work/repo" config core.sparseCheckout true \
        && git -C "$_work/repo" sparse-checkout init --cone >/dev/null 2>&1 \
        && git -C "$_work/repo" sparse-checkout set "$3" >/dev/null 2>&1 \
        && git -C "$_work/repo" fetch --depth=1 --filter=blob:none -q origin "$2" 2>/dev/null \
        && git -C "$_work/repo" checkout -q FETCH_HEAD 2>/dev/null \
        && [ -d "$_work/repo/$3" ]; then
        mkdir -p "$4"
        cp -rf "$_work/repo/$3/." "$4/"
        LB_FETCHED_COMMIT=$(git -C "$_work/repo" rev-parse HEAD)
        rm -rf "$_work"
        return 0
    fi
    rm -rf "$_work"
    return 1
}

# lb_latest_upstream_tag <url> - highest self-hosted/v* tag. Fails if the
# remote cannot be reached, prints nothing if there are no tags.
lb_latest_upstream_tag() {
    _refs=$(git ls-remote --tags --refs "$1" 2>/dev/null) || return 1
    printf '%s\n' "$_refs" \
        | sed 's#^.*refs/tags/##' \
        | grep -E '^self-hosted/v[0-9]' \
        | sort -V | tail -n1
}

# lb_copy_upstream <snapshot-docker-dir> <manifest-file> - copy upstream files,
# skipping anything LibreBeats owns.
lb_copy_upstream() {
    ( cd "$1" && find . -type f ) | sed 's|^\./||' | while IFS= read -r f; do
        grep -qxF "$f" "$2" 2>/dev/null && continue
        mkdir -p "$(dirname "$f")"
        cp -f "$1/$f" "$f"
    done
}

# lb_prune_extras <snapshot-docker-dir> <manifest-file> - delete project files
# that neither upstream nor LibreBeats ships and that are not user data.
lb_prune_extras() {
    ( find . -type f ) | sed 's|^\./||' | while IFS= read -r f; do
        case "$f" in
            .env|.env.*|.supabase-version|.librebeats-version|.librebeats/*) continue ;;
            backups/*|volumes/db/data/*|volumes/storage/*|volumes/snippets/*) continue ;;
            service/audio/cookies.txt) continue ;;
        esac
        [ -f "$1/$f" ] && continue
        grep -qxF "$f" "$2" 2>/dev/null && continue
        rm -f "$f"
    done
}

# lb_put <src> <dest> - copy a file. The running script is never overwritten in
# place: its replacement is written as <name>.new and moved in by
# lb_apply_deferred once the script has finished.
lb_put() {
    _dest="$2"
    if [ -n "$LB_SELF" ] && [ "$_dest" = "$LB_SELF" ]; then
        _dest="$2.new"
        LB_DEFERRED_LIST="$LB_DEFERRED_LIST $2"
    fi
    mkdir -p "$(dirname "$_dest")"
    cp -f "$1" "$_dest"
}

lb_apply_deferred() {
    for _f in $LB_DEFERRED_LIST; do
        [ -f "$_f.new" ] && mv -f "$_f.new" "$_f"
    done
    LB_DEFERRED_LIST=""
}

# lb_install <layer-dir> - write the LibreBeats files, the manifest and the
# base copies that the next update merges against.
lb_install() {
    mkdir -p .librebeats "$LB_BASE_DIR"
    lb_expand "$1" > "$LB_MANIFEST_FILE.tmp"
    while IFS= read -r f; do
        [ -n "$f" ] || continue
        lb_put "$1/$f" "$f"
        lb_put "$1/$f" "$LB_BASE_DIR/$f"
    done < "$LB_MANIFEST_FILE.tmp"
    mv -f "$LB_MANIFEST_FILE.tmp" "$LB_MANIFEST_FILE"
}

# lb_diff_report <layer-dir> - what lb_install is about to change.
lb_diff_report() {
    lb_expand "$1" | while IFS= read -r f; do
        if [ ! -f "$f" ]; then
            echo "  + $f"
        elif ! cmp -s "$f" "$1/$f"; then
            echo "  ~ $f (replaced; your copy is in the backup)"
        fi
    done
}

# lb_render_nginx <template> <domain> - the host nginx server block.
lb_render_nginx() {
    sed "s|\${DOMAIN}|$2|g" "$1"
}

# lb_generate_keys - secrets and API keys. The key scripts print secrets, so
# their output is discarded here.
lb_generate_keys() {
    sh utils/generate-keys.sh --update-env >/dev/null 2>&1 \
        || lb_die "utils/generate-keys.sh failed"
    sh utils/add-new-auth-keys.sh --update-env >/dev/null 2>&1 \
        || lb_die "utils/add-new-auth-keys.sh failed (needs node >= 16 or docker)"
    rm -f .env.old docker-compose.yml.old
}

# lb_check_cookies <file> - the file must be a Netscape cookies file, the format
# yt-dlp reads: a "Netscape HTTP Cookie File" header, then one cookie per line
# with seven tab-separated fields. CRLF line endings are accepted. A problem is
# printed on stdout and the function returns 1. A file whose cookies have all
# expired only warns, on stderr.
lb_check_cookies() {
    if [ ! -f "$1" ]; then
        echo "file not found: $1"
        return 1
    fi
    _clean=$(mktemp) || { echo "cannot create a temporary file"; return 1; }
    tr -d '\r' < "$1" > "$_clean"
    _first=$(head -n1 "$_clean")
    if ! printf '%s\n' "$_first" | grep -qE '^#[[:space:]]*(Netscape HTTP Cookie File|HTTP Cookie File)'; then
        rm -f "$_clean"
        echo "not in Netscape cookie format: the first line must be '# Netscape HTTP Cookie File'. Export cookies.txt from your browser; JSON and CSV exports are rejected."
        return 1
    fi
    _out=$(awk -F '\t' -v now="$(date +%s)" '
        BEGIN { total = 0; live = 0; err = "" }
        err != "" { next }
        /^#HttpOnly_/ { sub(/^#HttpOnly_/, "") }
        /^[ \t]*$/ { next }
        /^#/ { next }
        {
            if (NF != 7) { err = sprintf("line %d has %d tab-separated fields, the Netscape format needs 7", NR, NF); next }
            if ($2 != "TRUE" && $2 != "FALSE") { err = sprintf("line %d: include-subdomains must be TRUE or FALSE", NR); next }
            if ($4 != "TRUE" && $4 != "FALSE") { err = sprintf("line %d: secure must be TRUE or FALSE", NR); next }
            if ($3 !~ /^\//) { err = sprintf("line %d: the path must start with /", NR); next }
            if ($5 !~ /^[0-9]+$/) { err = sprintf("line %d: the expiry must be a whole number of seconds", NR); next }
            total++
            if ($5 + 0 == 0 || $5 + 0 > now + 0) live++
        }
        END {
            if (err != "") { print err; exit 1 }
            if (total == 0) { print "the file has a header but no cookies"; exit 1 }
            printf "%d %d\n", total, live
        }
    ' "$_clean")
    _rc=$?
    rm -f "$_clean"
    if [ "$_rc" -ne 0 ]; then
        echo "$_out"
        return 1
    fi
    if [ "${_out#* }" -eq 0 ]; then
        echo "WARN: every cookie in $1 has expired; export a fresh file from the browser" >&2
    fi
    return 0
}

LB_FAILS=0
lb_fail() { printf 'FAIL: %s\n' "$*"; LB_FAILS=$((LB_FAILS + 1)); }
lb_note() { printf 'WARN: %s\n' "$*"; }

# lb_preflight - prints FAIL and WARN lines, returns the number of failures.
lb_preflight() {
    LB_FAILS=0
    if [ ! -f .env ]; then
        lb_fail ".env is missing. Run setup.sh first."
        return 1
    fi
    [ -f docker-compose.yml ] || lb_fail "docker-compose.yml is missing"

    _compose=$(env_get COMPOSE_FILE)
    [ -n "$_compose" ] || _compose=docker-compose.yml
    case ":$_compose:" in
        *:docker-compose.yml:*) ;;
        *) lb_fail "COMPOSE_FILE must include docker-compose.yml (got: $_compose)" ;;
    esac
    _old_ifs=$IFS; IFS=:
    for _cf in $_compose; do
        [ -f "$_cf" ] || lb_fail "COMPOSE_FILE lists $_cf, which does not exist"
    done
    IFS=$_old_ifs

    case "$(env_get JWT_SECRET)" in
        ""|your-super-secret-jwt-token*) lb_fail "JWT_SECRET is empty or still the template value (sh utils/generate-keys.sh --update-env)" ;;
    esac
    case "$(env_get POSTGRES_PASSWORD)" in
        ""|your-super-secret-and-long-postgres-password) lb_fail "POSTGRES_PASSWORD is empty or still the template value" ;;
    esac
    case "$(env_get DASHBOARD_PASSWORD)" in
        ""|this_password_is_insecure_and_should_be_updated) lb_fail "DASHBOARD_PASSWORD is empty or still the template value" ;;
    esac
    case "$(env_get SECRET_KEY_BASE)" in
        ""|UpNVntn3cDxHJpq99YMc1T1AQgQpc8kfYTuRgBiYa15BLrx8etQoXz3gZv1/u2oq) lb_fail "SECRET_KEY_BASE is empty or still the template value" ;;
    esac
    case "$(env_get ANON_KEY)" in
        ""|eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAg*) lb_fail "ANON_KEY is empty or still the demo key" ;;
    esac
    case "$(env_get SERVICE_ROLE_KEY)" in
        ""|eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyAgCiAg*) lb_fail "SERVICE_ROLE_KEY is empty or still the demo key" ;;
    esac
    [ -n "$(env_get SUPABASE_PUBLISHABLE_KEY)" ] || lb_fail "SUPABASE_PUBLISHABLE_KEY is empty (sh utils/add-new-auth-keys.sh --update-env)"

    case ",$(env_get PGRST_DB_SCHEMAS)," in
        *,librebeats,*) ;;
        *) lb_fail "PGRST_DB_SCHEMAS must include librebeats, or the app's catalog queries fail" ;;
    esac

    _url=$(env_get SUPABASE_PUBLIC_URL)
    case "$_url" in
        https://*)
            case "$_url" in
                *localhost*|*127.0.0.1*) lb_fail "SUPABASE_PUBLIC_URL points at localhost ($_url); use the public https domain" ;;
            esac ;;
        *) lb_fail "SUPABASE_PUBLIC_URL must be an https:// URL (got: ${_url:-unset})" ;;
    esac

    if [ ! -f service/audio/cookies.txt ]; then
        lb_fail "service/audio/cookies.txt is missing. Copy your yt-dlp cookies file there (it is git-ignored)."
    elif _cerr=$(lb_check_cookies service/audio/cookies.txt); then
        :
    else
        lb_fail "service/audio/cookies.txt: $_cerr"
    fi

    for _f in docker-compose*.yml volumes/db/jwt.sql volumes/proxy/caddy/Caddyfile volumes/proxy/nginx/supabase-nginx.conf.tpl; do
        [ -f "$_f" ] && grep -q '^<<<<<<< ' "$_f" && lb_fail "$_f has unresolved merge conflict markers"
    done

    if command -v docker >/dev/null 2>&1; then
        docker compose config -q >/dev/null 2>&1 || lb_fail "docker compose config failed; check COMPOSE_FILE and the compose files"
    else
        lb_fail "docker is not installed or not on PATH"
    fi

    _mode=$(lb_mode)
    if [ "$_mode" = host ]; then
        case "$(env_get API_GW_HTTP_PORT)" in
            127.0.0.1:*) ;;
            *) lb_fail "API_GW_HTTP_PORT must bind loopback (127.0.0.1:8000) when nginx runs on the host; the API would otherwise be exposed without TLS" ;;
        esac
    else
        _domain=$(env_get PROXY_DOMAIN)
        case "$_domain" in
            ""|your-domain.example.com) lb_fail "PROXY_DOMAIN is empty or still the template value" ;;
        esac
        case "$(env_get CERTBOT_EMAIL)" in
            ""|*@example.com) lb_fail "CERTBOT_EMAIL must be a real mailbox (Let's Encrypt sends expiry notices there)" ;;
        esac
        if command -v ss >/dev/null 2>&1; then
            _busy=$(ss -ltnp 2>/dev/null | awk '$4 ~ /:(80|443)$/' | grep -v docker || true)
            [ -z "$_busy" ] || lb_fail "ports 80 or 443 are used by another process; stop host nginx or set up the host mode instead"
        else
            lb_note "ss is not available, port 80/443 check skipped"
        fi
        if command -v getent >/dev/null 2>&1 && [ -n "$_domain" ] \
            && ! getent hosts "$_domain" >/dev/null 2>&1; then
            lb_note "$_domain does not resolve yet; Let's Encrypt will fail until DNS points at this server"
        fi
    fi

    if [ -f "$LB_BASE_DIR/docker-compose.yml" ] && ! cmp -s docker-compose.yml "$LB_BASE_DIR/docker-compose.yml"; then
        lb_note "docker-compose.yml differs from the LibreBeats version; put your changes in docker-compose.override.yml"
    fi

    if [ "$LB_FAILS" -eq 0 ]; then
        echo "preflight: ok ($_mode proxy)"
    else
        echo "preflight: $LB_FAILS problem(s) found"
    fi
    return "$LB_FAILS"
}
