#!/bin/bash
set -e

echo "Installing Chrome, RustDesk, and rclone..."

sudo apt-get update
sudo apt-get install -y wget gnupg ca-certificates curl fuse3

# Install Google Chrome
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub \
  | sudo gpg --dearmor -o /usr/share/keyrings/google-linux-signing-key.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/google-linux-signing-key.gpg] http://dl.google.com/linux/chrome/deb/ stable main" \
  | sudo tee /etc/apt/sources.list.d/google-chrome.list > /dev/null

sudo apt-get update
sudo apt-get install -y google-chrome-stable

# Install RustDesk latest release .deb
RUSTDESK_TAG=$(curl -fsSL https://api.github.com/repos/rustdesk/rustdesk/releases/latest | grep '"tag_name"' | head -n 1 | cut -d '"' -f 4)
RUSTDESK_DEB="rustdesk-${RUSTDESK_TAG}-amd64.deb"
RUSTDESK_URL="https://github.com/rustdesk/rustdesk/releases/download/${RUSTDESK_TAG}/${RUSTDESK_DEB}"

curl -fL -o "/tmp/${RUSTDESK_DEB}" "$RUSTDESK_URL"
sudo apt-get install -y "/tmp/${RUSTDESK_DEB}"

# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Prepare Google Drive mount point
mkdir -p /home/vscode/GoogleDrive
chown -R vscode:vscode /home/vscode/GoogleDrive

# Create a helper script so a user can mount Drive after one-time auth
mkdir -p /home/vscode/.local/bin
cat > /home/vscode/.local/bin/connect-google-drive <<'EOF'
#!/bin/bash
set -e

mkdir -p "$HOME/GoogleDrive"

if [ ! -f "$HOME/.config/rclone/rclone.conf" ]; then
  echo "No rclone config found yet. Run 'rclone config' once to authenticate Google Drive."
  exit 1
fi

if ! mountpoint -q "$HOME/GoogleDrive"; then
  rclone mount gdrive: "$HOME/GoogleDrive" --daemon --allow-other --vfs-cache-mode writes
fi

echo "Google Drive mounted at $HOME/GoogleDrive"
EOF
chmod +x /home/vscode/.local/bin/connect-google-drive
chown -R vscode:vscode /home/vscode/.local

# If the user has already authenticated Drive in this container, mount it automatically
if [ -f /home/vscode/.config/rclone/rclone.conf ]; then
  if ! mountpoint -q /home/vscode/GoogleDrive; then
    rclone mount gdrive: /home/vscode/GoogleDrive --daemon --allow-other --vfs-cache-mode writes || true
  fi
fi

echo "Chrome, RustDesk, and rclone installed successfully."
echo "For RustDesk: open the RustDesk app inside the desktop and it will show the ID/password."
echo "For Google Drive: run 'rclone config' once to authenticate, then use:"
echo "  /home/vscode/.local/bin/connect-google-drive"
