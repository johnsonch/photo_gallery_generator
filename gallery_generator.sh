#!/bin/bash
set -euo pipefail

# ---------------------------------------------------------------------------
# gallery_generator.sh — Generate and deploy password-protected photo galleries
# ---------------------------------------------------------------------------

# ── Help / Usage ──────────────────────────────────────────────────────────────

usage() {
    cat <<'USAGE'
Usage: gallery_generator.sh [--overwrite] <folder_path> <gallery_name> <username> <password>

Generate a password-protected photo gallery from a folder of images and deploy
it to a remote server via SSH/rsync.

Options:
  --overwrite   Remove the existing remote gallery before deploying.
                Replaces all files on the server for this gallery.

Arguments:
  folder_path   Path to a local folder containing images (jpg, jpeg, png, gif)
  gallery_name  Name for the gallery on the remote server (used in the URL)
  username      Username for HTTP Basic Auth on the gallery
  password      Password for HTTP Basic Auth on the gallery

Required environment variables:
  GALLERY_SSH_USER          SSH username for the remote host
  GALLERY_REMOTE_DOMAIN     Domain of the remote server (e.g. photos.example.com)

Optional environment variables:
  GALLERY_REMOTE_BASE_PATH  Base path on the remote server
                            (default: /home/$GALLERY_SSH_USER/$GALLERY_REMOTE_DOMAIN)
  GALLERY_TIP_URL           URL for a tip/support button shown on the gallery
                            (e.g. https://account.venmo.com/u/yourname)
  GALLERY_ASSETS_DIR        Directory containing PHP/CSS assets
                            (default: script directory, then /usr/local/share/gallery_generator)

Environment variables can also be set in ~/.gallery_generator.env

Gallery log:
  Each deploy is recorded in ~/.gallery_generator.log with the date, URL,
  username, and password. View it with: cat ~/.gallery_generator.log

Dependencies:
  ImageMagick (magick/convert), rsync, htpasswd (apache2-utils), ssh

Examples:
  # Set up env and generate a gallery
  export GALLERY_SSH_USER=myuser
  export GALLERY_REMOTE_DOMAIN=photos.example.com
  ./gallery_generator.sh ./vacation-pics vacation-2026 guest secretpass

  # Overwrite an existing gallery with new photos
  ./gallery_generator.sh --overwrite ./vacation-pics vacation-2026 guest secretpass

  # With a tip button
  export GALLERY_TIP_URL="https://account.venmo.com/u/myname"
  ./gallery_generator.sh ./wedding-pics smith-wedding viewer pass123
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

# ── Parse flags ──────────────────────────────────────────────────────────────

OVERWRITE=false

while [[ "${1:-}" == --* ]]; do
    case "$1" in
        --overwrite) OVERWRITE=true; shift ;;
        *) echo "Error: Unknown option: $1" >&2; echo "Run '$0 --help' for usage." >&2; exit 1 ;;
    esac
done

# ── Source env file if present ────────────────────────────────────────────────

if [[ -f "${HOME}/.gallery_generator.env" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.gallery_generator.env"
fi

# ── Validate required environment variables ───────────────────────────────────

missing_vars=()
[[ -z "${GALLERY_SSH_USER:-}" ]] && missing_vars+=("GALLERY_SSH_USER")
[[ -z "${GALLERY_REMOTE_DOMAIN:-}" ]] && missing_vars+=("GALLERY_REMOTE_DOMAIN")

if [[ ${#missing_vars[@]} -gt 0 ]]; then
    echo "Error: Required environment variables are not set:" >&2
    for var in "${missing_vars[@]}"; do
        echo "  - $var" >&2
    done
    echo "" >&2
    echo "Set them in your shell or in ~/.gallery_generator.env" >&2
    echo "See .env.example for a template, or run: $0 --help" >&2
    exit 1
fi

SSH_USER="${GALLERY_SSH_USER}"
REMOTE_DOMAIN="${GALLERY_REMOTE_DOMAIN}"
REMOTE_BASE_PATH="${GALLERY_REMOTE_BASE_PATH:-/home/${SSH_USER}/${REMOTE_DOMAIN}}"

# ── Validate arguments ───────────────────────────────────────────────────────

if [[ $# -ne 4 ]]; then
    echo "Error: Expected 4 arguments, got $#" >&2
    echo "Usage: $0 <folder_path> <gallery_name> <username> <password>" >&2
    echo "Run '$0 --help' for more information." >&2
    exit 1
fi

FOLDER_PATH="$1"
GALLERY_NAME="$2"
USERNAME="$3"
PASSWORD="$4"

if [[ ! -d "$FOLDER_PATH" ]]; then
    echo "Error: Folder does not exist: $FOLDER_PATH" >&2
    exit 1
fi

# ── Resolve asset directory ──────────────────────────────────────────────────

# Resolve through symlinks so assets are found when invoked via a symlink
SOURCE="$0"
while [[ -L "$SOURCE" ]]; do
    DIR="$(cd "$(dirname "$SOURCE")" && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SOURCE")" && pwd)"

if [[ -n "${GALLERY_ASSETS_DIR:-}" && -d "${GALLERY_ASSETS_DIR}" ]]; then
    ASSETS_DIR="${GALLERY_ASSETS_DIR}"
elif [[ -f "${SCRIPT_DIR}/index.php" ]]; then
    ASSETS_DIR="${SCRIPT_DIR}"
else
    echo "Error: Cannot find gallery assets (PHP/CSS files)." >&2
    echo "Set GALLERY_ASSETS_DIR or run from the source directory." >&2
    exit 1
fi

# ── Check local dependencies ────────────────────────────────────────────────

echo "Checking dependencies..."

deps_ok=true

if ! command -v magick &>/dev/null && ! command -v convert &>/dev/null; then
    echo "Error: ImageMagick is required but not installed." >&2
    deps_ok=false
fi

if ! command -v rsync &>/dev/null; then
    echo "Error: rsync is required but not installed." >&2
    deps_ok=false
fi

if ! command -v htpasswd &>/dev/null; then
    echo "Error: htpasswd is required but not installed." >&2
    deps_ok=false
fi

if ! command -v ssh &>/dev/null; then
    echo "Error: ssh is required but not installed." >&2
    deps_ok=false
fi

if [[ "$deps_ok" == false ]]; then
    echo "Install missing dependencies and try again." >&2
    exit 1
fi

echo "All dependencies found."

# ── Remote server pre-flight checks ──────────────────────────────────────────

REMOTE_HOST="${SSH_USER}@${REMOTE_DOMAIN}"
REMOTE_PATH="${REMOTE_BASE_PATH}/${GALLERY_NAME}"

echo "Testing connection to ${REMOTE_HOST}..."

if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${REMOTE_HOST}" exit 2>/dev/null; then
    echo "Error: Cannot connect to ${REMOTE_HOST} via SSH." >&2
    echo "Verify that:" >&2
    echo "  - GALLERY_SSH_USER (${SSH_USER}) is correct" >&2
    echo "  - GALLERY_REMOTE_DOMAIN (${REMOTE_DOMAIN}) is correct" >&2
    echo "  - Your SSH key is configured for this host" >&2
    exit 1
fi

if ! ssh -o ConnectTimeout=10 "${REMOTE_HOST}" "test -d '${REMOTE_BASE_PATH}'" 2>/dev/null; then
    echo "Error: Remote base path does not exist: ${REMOTE_BASE_PATH}" >&2
    echo "Create it on the server or set GALLERY_REMOTE_BASE_PATH." >&2
    exit 1
fi

if ! ssh -o ConnectTimeout=10 "${REMOTE_HOST}" "test -w '${REMOTE_BASE_PATH}'" 2>/dev/null; then
    echo "Error: Remote base path is not writable: ${REMOTE_BASE_PATH}" >&2
    exit 1
fi

echo "Remote server checks passed."

# ── Generate thumbnails ──────────────────────────────────────────────────────

THUMB_DIR="${FOLDER_PATH}/thumbnails"
THUMB_SIZE="600"

mkdir -p "$THUMB_DIR"

echo "Processing folder: $FOLDER_PATH"
echo "Generating thumbnails in $THUMB_DIR"

find "$FOLDER_PATH" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | while read -r img; do
    filename=$(basename "$img")
    thumb_path="$THUMB_DIR/$filename"

    if [[ ! -f "$thumb_path" ]]; then
        echo "Creating thumbnail for: $filename"
        magick "$img" -resize "${THUMB_SIZE}^" -gravity center -extent "$THUMB_SIZE" "$thumb_path"
    else
        echo "Thumbnail already exists for: $filename"
    fi
done

# ── Copy asset files into gallery folder ─────────────────────────────────────

for file in "${ASSETS_DIR}"/*.{php,js,css}; do
    if [[ -f "$file" ]]; then
        cp "$file" "${FOLDER_PATH}/$(basename "$file")"
    fi
done
echo "Gallery files copied successfully to $FOLDER_PATH"

# ── Configure tip URL in index.php ───────────────────────────────────────────

if [[ -n "${GALLERY_TIP_URL:-}" ]]; then
    sed -i.bak "s|%%GALLERY_TIP_URL%%|${GALLERY_TIP_URL}|g" "${FOLDER_PATH}/index.php"
    rm -f "${FOLDER_PATH}/index.php.bak"
else
    sed -i.bak '/%%GALLERY_TIP_URL%%/d' "${FOLDER_PATH}/index.php"
    rm -f "${FOLDER_PATH}/index.php.bak"
fi

# ── Generate authentication files ────────────────────────────────────────────

htpasswd -bc "$FOLDER_PATH/.htpasswd" "$USERNAME" "$PASSWORD"

cat > "$FOLDER_PATH/.htaccess" << EOF
AuthType Basic
AuthName "Restricted Gallery"
AuthUserFile ${REMOTE_PATH}/.htpasswd
Require valid-user
EOF

echo "Authentication files created successfully"

# ── Deploy to remote server ──────────────────────────────────────────────────

if [[ "$OVERWRITE" == true ]]; then
    echo "Overwrite enabled — removing existing gallery at ${REMOTE_PATH}..."
    ssh "$REMOTE_HOST" "rm -rf '${REMOTE_PATH}'"
fi

ssh "$REMOTE_HOST" "mkdir -p '${REMOTE_PATH}'"

rsync -av "$FOLDER_PATH"/{*,.htaccess,.htpasswd} "$REMOTE_HOST:$REMOTE_PATH/"

echo "Files transferred successfully to $REMOTE_HOST:$REMOTE_PATH"

# ── Clean up local generated files ───────────────────────────────────────────

rm -rf "$FOLDER_PATH/thumbnails" "$FOLDER_PATH"/*.{php,js,css} "$FOLDER_PATH"/.htaccess "$FOLDER_PATH"/.htpasswd
echo "Local generated files cleaned up"

# ── Log gallery to local ledger ──────────────────────────────────────────────

GALLERY_LOG="${HOME}/.gallery_generator.log"
GALLERY_URL="https://${REMOTE_DOMAIN}/${GALLERY_NAME}"

{
    echo "$(date +%Y-%m-%d)  ${GALLERY_URL}  ${USERNAME}  ${PASSWORD}"
} >> "$GALLERY_LOG"

# ── Output gallery URL ───────────────────────────────────────────────────────

echo ""
echo "Gallery available at: ${GALLERY_URL}"
echo "Username: $USERNAME"
echo "Password: $PASSWORD"
