# Photo Gallery Generator

Generate password-protected photo galleries and deploy them to a remote server with a single command.

## Features

- Generates responsive image galleries with thumbnails
- Password-protects galleries with HTTP Basic Auth
- Deploys to any server via SSH/rsync
- Full-size image viewing with previous/next navigation
- Bulk download of all images as a zip file
- Optional tip/support button
- Mobile-friendly responsive design

## Requirements

- **ImageMagick** — thumbnail generation
- **rsync** — file transfer to the remote server
- **htpasswd** (apache2-utils) — generating authentication files
- **ssh** — remote server access with key-based auth configured

Check dependencies with:

```sh
make deps
```

## Installation

```sh
git clone https://github.com/yourusername/photo_gallery_generator.git
cd photo_gallery_generator
make deps      # check for required tools
sudo make install
make setup     # interactive env var configuration
```

This symlinks `gallery_generator` into `/usr/local/bin` pointing back to the repo, so the project just needs to stay where you cloned it. Updates via `git pull` take effect immediately.

To uninstall:

```sh
sudo make uninstall
```

You can also run the script directly from the repo without installing:

```sh
./gallery_generator.sh <folder_path> <username> <password>
```

## Configuration

The easiest way to configure is the interactive setup wizard:

```sh
make setup
```

This walks you through each setting and writes `~/.gallery_generator.env`.

You can also configure manually:

```sh
cp .env.example ~/.gallery_generator.env
# Edit ~/.gallery_generator.env with your values
```

| Variable | Required | Description |
|---|---|---|
| `GALLERY_SSH_USER` | Yes | SSH username for the remote host |
| `GALLERY_REMOTE_DOMAIN` | Yes | Domain of the remote server |
| `GALLERY_REMOTE_BASE_PATH` | No | Base path on the server (default: `/home/$GALLERY_SSH_USER/$GALLERY_REMOTE_DOMAIN`) |
| `GALLERY_TIP_URL` | No | URL for a tip/support button on galleries |
| `GALLERY_ASSETS_DIR` | No | Custom path to PHP/CSS assets |

## Usage

```sh
gallery_generator <folder_path> <gallery_name> <username> <password>
```

**Arguments:**

- `folder_path` — Path to a local folder containing images
- `gallery_name` — Name for the gallery on the remote server (used in the URL)
- `username` — Username for gallery access
- `password` — Password for gallery access

**Examples:**

```sh
# Generate a gallery from vacation photos
gallery_generator ./vacation-pics vacation-2026 guest secretpass

# With a tip button
export GALLERY_TIP_URL="https://account.venmo.com/u/yourname"
gallery_generator ./wedding-photos smith-wedding viewer pass123
```

## How It Works

1. Validates environment variables, arguments, and dependencies
2. Tests SSH connectivity to the remote server
3. Generates square thumbnails for each image using ImageMagick
4. Copies PHP/CSS gallery files into the image folder
5. Creates `.htpasswd` and `.htaccess` files for password protection
6. Deploys everything to the remote server via rsync
7. Cleans up local generated files
8. Prints the gallery URL with credentials

## License

MIT — see [LICENSE](LICENSE) for details.
