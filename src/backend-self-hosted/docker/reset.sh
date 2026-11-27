#!/bin/sh
#
# Reset a LibreBeats deployment to the state setup.sh produced: the same
# Supabase release, the same LibreBeats layer, the same URLs and proxy mode,
# fresh secrets and an empty database. The deployment is archived to backups/
# before anything is deleted.
#
# Usage:
#   sh reset.sh                 # asks you to type 'reset'
#   sh reset.sh --yes           # no prompt
#   sh reset.sh --purge-certs   # also delete the Let's Encrypt volumes (docker proxy)
#
# Kept: backups/, the Let's Encrypt volumes (unless --purge-certs), and
# service/audio/cookies.txt. Everything else in the deployment is rebuilt.
#
# Env:
#   SUPABASE_REPO_URL   upstream repository (default: github supabase/supabase)

set -e

cd "$(dirname "$0")"

LB_SELF="reset.sh"
. ./librebeats-lib.sh

ASSUME_YES=0
PURGE_CERTS=0
REPO_URL="${SUPABASE_REPO_URL:-https://github.com/supabase/supabase}"

while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y) ASSUME_YES=1; shift ;;
        --purge-certs) PURGE_CERTS=1; shift ;;
        -h|--help) awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"; exit 0 ;;
        *) lb_die "Unknown option: $1" ;;
    esac
done

[ -f "$LB_STAMP" ] && [ -f "$LB_MANIFEST_FILE" ] \
    || lb_die "This is not a LibreBeats deployment (no $LB_STAMP). Run setup.sh instead."
[ -f .env ] || lb_die ".env is missing, so there is nothing to reset from."

UP_REF=$(grep -E '^ref=' .supabase-version 2>/dev/null | head -n1 | cut -d= -f2-)
[ -n "$UP_REF" ] || lb_die ".supabase-version has no ref=, so the Supabase release is unknown"
LB_URL=$(lb_stamp_get librebeats_url)
LB_REF=$(lb_stamp_get librebeats_ref)
LB_COMMIT=$(lb_stamp_get librebeats_commit)
NGINX_SHA=$(lb_stamp_get nginx_sha256)

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
cp .env "$TMP/old.env"

if [ "$ASSUME_YES" != "1" ]; then
    echo "This deletes the database, storage, SQL snippets and all secrets, and rebuilds"
    echo "the deployment from $UP_REF and the LibreBeats layer. A full archive goes to backups/ first."
    if ! ( : < /dev/tty ) 2>/dev/null; then
        lb_die "No terminal to confirm on. Re-run with --yes."
    fi
    printf "Type 'reset' to continue: " > /dev/tty
    read -r _reply < /dev/tty
    [ "$_reply" = "reset" ] || lb_die "Aborted. Nothing was changed."
fi

mkdir -p backups
ARCHIVE="backups/reset-$(date +%Y%m%d-%H%M%S).tgz"
tar czf "$ARCHIVE" \
    --exclude='./backups' --exclude='./volumes/db/data' --exclude='./volumes/storage' . 2>/dev/null \
    || lb_warn "the archive reported errors; check $ARCHIVE before relying on it"
chmod 600 "$ARCHIVE"
lb_log "Archived the deployment to $ARCHIVE"

if command -v docker >/dev/null 2>&1; then
    lb_log "Stopping the stack and removing its volumes"
    docker compose down --remove-orphans >/dev/null 2>&1 \
        || lb_warn "docker compose down reported an error (the stack may not have been running)"
    for _v in $(docker volume ls -q 2>/dev/null | grep '^supabase_' || true); do
        case "$_v" in
            *_nginx_letsencrypt|*_caddy_data|*_caddy_config)
                if [ "$PURGE_CERTS" != "1" ]; then
                    echo "keeping $_v (Let's Encrypt certificates; --purge-certs deletes it)"
                    continue
                fi ;;
        esac
        docker volume rm "$_v" >/dev/null 2>&1 || lb_warn "could not remove volume $_v"
    done
    docker run --rm -v "$(pwd)/volumes:/v" alpine \
        sh -c 'rm -rf /v/db/data /v/storage; rm -rf /v/snippets/*' >/dev/null 2>&1 \
        || lb_warn "could not wipe volumes/ through a container; remove volumes/db/data and volumes/storage by hand"
else
    lb_warn "docker not found: containers and volumes were not touched"
fi

lb_log "Rebuilding files from $UP_REF and the LibreBeats layer"
rm -f .env.old docker-compose.yml.old
UP_SNAP="$TMP/upstream"
lb_fetch "$REPO_URL" "$UP_REF" docker "$UP_SNAP" \
    || lb_die "Could not fetch $UP_REF from $REPO_URL. Check the network and re-run."
lb_copy_upstream "$UP_SNAP" "$LB_MANIFEST_FILE"
lb_prune_extras "$UP_SNAP" "$LB_MANIFEST_FILE"

while IFS= read -r _f; do
    [ -n "$_f" ] || continue
    [ -f "$LB_BASE_DIR/$_f" ] || lb_die "missing base copy for $_f; run sh update.sh --adopt or reinstall"
    lb_put "$LB_BASE_DIR/$_f" "$_f"
done < "$LB_MANIFEST_FILE"

lb_log "Rebuilding .env (URLs, proxy mode and certificate settings are kept)"
cp .env.example .env
for _k in $LB_ENV_CARRY; do
    _v=$(env_get_file "$TMP/old.env" "$_k")
    if [ -n "$_v" ]; then
        env_set "$_k" "$_v"
    fi
done
env_set PGRST_DB_SCHEMAS "public,librebeats"

lb_log "Generating new secrets and API keys"
lb_generate_keys

lb_write_stamps "$UP_REF" "$LB_URL" "$LB_REF" "$LB_COMMIT" "$NGINX_SHA"
lb_apply_deferred

if lb_preflight; then
    echo ""
    lb_log "Reset complete. Start the stack with: sh run.sh start"
else
    lb_die "Reset finished but the preflight found problems (listed above). Fix them, then run: sh update.sh --check"
fi
