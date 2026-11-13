#!/bin/sh
#
# Install LibreBeats on a Supabase self-hosted release.
#
# Run this from the LibreBeats checkout (src/backend-self-hosted/docker). It
# builds the deployment directory from upstream's release plus the LibreBeats
# layer (see librebeats-lib.sh), then runs the preflight. Later changes go
# through update.sh and reset.sh inside the deployment directory.
#
# Usage:
#   sh setup.sh --public-url https://beats.example.com --proxy host
#   sh setup.sh --public-url https://beats.example.com --proxy docker \
#               --certbot-email you@example.com --cookies ~/cookies.txt
#
# Options:
#   -p, --project-dir <dir>   deployment directory (default: supabase-project)
#   --public-url <url>        public https URL of the stack
#   --proxy host|docker       host: nginx on this server (you manage it);
#                             docker: the bundled nginx-certbot container
#   --proxy-domain <host>     certificate domain (default: host of --public-url)
#   --certbot-email <email>   Let's Encrypt contact (docker mode)
#   --cookies <file>          yt-dlp cookies, copied to service/audio/cookies.txt
#   --ref <tag|branch>        upstream ref (default: latest self-hosted/v* tag)
#   --head                    upstream default branch instead of a release tag
#   --skip-deps               do not install system packages
#   -y, --yes                 no prompts; required values must come from flags
#   -h, --help                show this help
#
# Environment:
#   SUPABASE_REPO_URL         upstream repository (default: github supabase/supabase)
#
# Documentation: src/backend-self-hosted/hosting-with-existing-nginx.md
#                src/backend-self-hosted/hosting-with-docker-nginx.md

set -e

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "$SCRIPT_DIR/librebeats-lib.sh"

PROJECT_DIR="supabase-project"
SKIP_DEPS=0
ASSUME_YES=0
SOURCE_REF=""
FORCE_HEAD=0
PUBLIC_URL=""
PROXY=""
PROXY_DOMAIN=""
CERTBOT_EMAIL=""
COOKIES=""
REPO_URL="${SUPABASE_REPO_URL:-https://github.com/supabase/supabase}"

print_help() {
    awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"
}

die() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
log() { printf '===> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }

while [ $# -gt 0 ]; do
    case "$1" in
        -p|--project-dir) PROJECT_DIR="$2"; shift 2 ;;
        --public-url) PUBLIC_URL="$2"; shift 2 ;;
        --proxy) PROXY="$2"; shift 2 ;;
        --proxy-domain) PROXY_DOMAIN="$2"; shift 2 ;;
        --certbot-email) CERTBOT_EMAIL="$2"; shift 2 ;;
        --cookies) COOKIES="$2"; shift 2 ;;
        --ref) SOURCE_REF="$2"; shift 2 ;;
        --head) FORCE_HEAD=1; shift ;;
        --skip-deps) SKIP_DEPS=1; shift ;;
        -y|--yes) ASSUME_YES=1; shift ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "Unknown option: $1" >&2; print_help; exit 1 ;;
    esac
done

if [ "$(id -u)" = "0" ]; then SUDO=""; else SUDO="sudo"; fi

# Prompt only when no flag was given and a terminal is available.
ask() {
    if [ "$ASSUME_YES" = "1" ] || ! ( : < /dev/tty ) 2>/dev/null; then
        printf '%s' "$2"
        return
    fi
    printf '%s [%s]: ' "$1" "$2" > /dev/tty
    read -r _reply < /dev/tty
    [ -z "$_reply" ] && _reply="$2"
    printf '%s' "$_reply"
}

# --- system packages (Linux only) -------------------------------------------

OS_FAMILY=""
OS_ID=""
OS_CODENAME=""

detect_os() {
    [ -f /etc/os-release ] || die "Cannot detect OS: /etc/os-release missing. Linux only."
    # shellcheck disable=SC1091
    . /etc/os-release
    OS_ID="$ID"
    OS_CODENAME="${VERSION_CODENAME:-}"
    case "$ID" in
        ubuntu|debian) OS_FAMILY="debian" ;;
        centos|rhel|fedora|rocky|almalinux|ol|amzn) OS_FAMILY="rhel" ;;
        *)
            case "${ID_LIKE:-}" in
                *debian*|*ubuntu*) OS_FAMILY="debian" ;;
                *rhel*|*fedora*|*centos*) OS_FAMILY="rhel" ;;
                *) die "Unsupported distribution: $ID" ;;
            esac
            ;;
    esac
    log "Detected OS: $ID ($OS_FAMILY)"
}

pkg_install() {
    if [ "$OS_FAMILY" = "debian" ]; then
        export DEBIAN_FRONTEND=noninteractive
        $SUDO apt-get install -qq -y "$@"
    else
        $SUDO dnf install -q -y "$@"
    fi
}

install_base_packages() {
    log "Installing base packages: git, openssl, jq, ca-certificates"
    if [ "$OS_FAMILY" = "debian" ]; then
        $SUDO apt-get update -qq -y
        pkg_install git openssl jq ca-certificates curl gnupg lsb-release
    else
        $SUDO dnf makecache -q -y || true
        pkg_install git openssl jq ca-certificates curl dnf-plugins-core
    fi
}

install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        log "Docker already installed: $(docker --version)"
        return 0
    fi

    log "Installing Docker Engine and Compose plugin"
    if [ "$OS_FAMILY" = "debian" ]; then
        $SUDO install -m 0755 -d /etc/apt/keyrings
        curl -fsSL "https://download.docker.com/linux/${OS_ID}/gpg" \
            | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
        $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
        codename="${OS_CODENAME:-$(lsb_release -cs 2>/dev/null || echo stable)}"
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/${OS_ID} ${codename} stable" \
            | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
        $SUDO apt-get update -qq -y
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    else
        repo_distro="centos"
        case "$OS_ID" in
            fedora) repo_distro="fedora" ;;
            rhel) repo_distro="rhel" ;;
        esac
        $SUDO dnf config-manager --add-repo "https://download.docker.com/linux/${repo_distro}/docker-ce.repo" 2>/dev/null \
            || $SUDO dnf-3 config-manager --add-repo "https://download.docker.com/linux/${repo_distro}/docker-ce.repo"
        pkg_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    fi

    $SUDO systemctl enable --now docker || warn "Could not enable docker via systemctl; start it manually."
    if [ -n "$SUDO" ]; then
        $SUDO usermod -aG docker "$(id -un)" 2>/dev/null \
            && warn "Added $(id -un) to the docker group. Log out and back in before running docker without sudo."
    fi
}

# --- main ---------------------------------------------------------------------

log "Setup starting"

if [ "$SKIP_DEPS" = "1" ]; then
    log "Skipping system packages (--skip-deps)"
else
    detect_os
    install_base_packages
    install_docker
fi

if [ -z "$PUBLIC_URL" ]; then
    PUBLIC_URL=$(ask "Public https URL of the stack (e.g. https://beats.example.com)" "")
fi
case "$PUBLIC_URL" in
    https://*) ;;
    *) die "--public-url must be an https:// URL (got: '${PUBLIC_URL:-empty}')" ;;
esac

if [ -z "$PROXY" ]; then
    PROXY=$(ask "Proxy: 'host' (nginx already on this server) or 'docker' (bundled nginx-certbot)" "host")
fi
case "$PROXY" in
    host|docker) ;;
    *) die "--proxy must be 'host' or 'docker' (got: '$PROXY')" ;;
esac

_default_domain=$(printf '%s' "$PUBLIC_URL" | sed -e 's|^https*://||' -e 's|[/:].*$||')
[ -n "$PROXY_DOMAIN" ] || PROXY_DOMAIN=$(ask "Certificate domain" "$_default_domain")

if [ "$PROXY" = docker ]; then
    if [ -z "$CERTBOT_EMAIL" ]; then
        CERTBOT_EMAIL=$(ask "Let's Encrypt contact email" "")
    fi
    [ -n "$CERTBOT_EMAIL" ] || die "--certbot-email is required with --proxy docker"
fi

if [ -n "$COOKIES" ]; then
    [ -f "$COOKIES" ] || die "--cookies file not found: $COOKIES"
    COOKIES_SRC="$COOKIES"
elif [ -f "$SCRIPT_DIR/service/audio/cookies.txt" ]; then
    COOKIES_SRC="$SCRIPT_DIR/service/audio/cookies.txt"
else
    COOKIES_SRC=""
    warn "No cookies file given (--cookies). The preflight will fail until service/audio/cookies.txt exists."
fi

[ ! -e "$PROJECT_DIR" ] || die "$PROJECT_DIR already exists. Pick another name with --project-dir."

if [ -n "$SOURCE_REF" ]; then
    REF="$SOURCE_REF"
elif [ "$FORCE_HEAD" = "1" ]; then
    REF="HEAD"
else
    REF=$(lb_latest_upstream_tag "$REPO_URL") \
        || die "Could not reach $REPO_URL to look up release tags. Check the network, or pass --ref <tag> or --head."
    if [ -z "$REF" ]; then
        warn "No self-hosted/v* release tag exists yet; using the default branch"
        REF="HEAD"
    fi
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
log "Fetching Supabase self-hosted files at $REF"
lb_fetch "$REPO_URL" "$REF" docker "$TMP/upstream" \
    || die "Could not fetch '$REF' from $REPO_URL"
UPSTREAM_COMMIT="$LB_FETCHED_COMMIT"

log "Creating deployment in $PROJECT_DIR"
mkdir -p "$PROJECT_DIR/.librebeats"
cd "$PROJECT_DIR"
lb_expand "$SCRIPT_DIR" > "$LB_MANIFEST_FILE"
lb_copy_upstream "$TMP/upstream" "$LB_MANIFEST_FILE"
log "Installing the LibreBeats layer"
lb_install "$SCRIPT_DIR"

if [ -n "$COOKIES_SRC" ]; then
    cp -f "$COOKIES_SRC" service/audio/cookies.txt
fi

log "Writing .env"
cp .env.example .env
env_set SUPABASE_PUBLIC_URL "$PUBLIC_URL"
env_set API_EXTERNAL_URL "$PUBLIC_URL/auth/v1"
env_set SITE_URL "$PUBLIC_URL"
env_set PGRST_DB_SCHEMAS "public,librebeats"
env_set PROXY_DOMAIN "$PROXY_DOMAIN"
env_set CERTBOT_EMAIL "$CERTBOT_EMAIL"
if [ "$PROXY" = docker ]; then
    env_set COMPOSE_FILE "docker-compose.yml:docker-compose.nginx.yml"
else
    env_set COMPOSE_FILE "docker-compose.yml"
    env_set API_GW_HTTP_PORT "127.0.0.1:8000"
fi

log "Generating secrets and API keys"
lb_generate_keys

LB_SOURCE_URL="${LIBREBEATS_REPO_URL:-$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "$LB_DEFAULT_REPO_URL")}"
LB_COMMIT=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "$SCRIPT_DIR" status --porcelain -- . 2>/dev/null)" ]; then
    warn "The LibreBeats checkout has uncommitted changes. Updates read the committed '$LB_DEFAULT_REF' branch, so these changes are not part of the recorded version."
fi
NGINX_SHA=$(sha256sum librebeats/nginx-host.conf.tpl | cut -d' ' -f1)
lb_write_stamps "$REF" "$LB_SOURCE_URL" "$LB_DEFAULT_REF" "$LB_COMMIT" "$NGINX_SHA"
log "Recorded upstream $REF (commit $UPSTREAM_COMMIT) and LibreBeats commit $LB_COMMIT"

if [ "$PROXY" = docker ]; then
    docker compose --progress quiet pull >/dev/null 2>&1 || warn "docker compose pull failed; retry with: sh run.sh pull"
fi

echo ""
if lb_preflight; then
    echo ""
    log "Setup complete. Deployment: $(pwd)"
    echo "Next steps:"
    echo "  cd $(pwd)"
    if [ "$PROXY" = host ]; then
        echo "  sh update.sh --nginx-snippet     # server block for your existing nginx"
    fi
    echo "  sh run.sh start"
else
    echo ""
    die "Setup finished but the preflight found problems (listed above). Fix them, then run: sh update.sh --check"
fi
