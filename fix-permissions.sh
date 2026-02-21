#!/bin/bash
# fix-permissions.sh - Fix Homebrew permissions for multi-user macOS systems
# https://github.com/brickhouse-tech/homebrew-multi-user
#
# Fixes:
# - /opt/homebrew ownership and permissions
# - Dedicated temp directory to prevent permission conflicts
# - System-wide HOMEBREW_TEMP environment variable
#
# Usage:
#   sudo ./fix-permissions.sh
#   sudo BREW_GROUP=staff ./fix-permissions.sh  # Custom group

set -e

# ── Configuration ─────────────────────────────────────────────────────────────

BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
BREW_GROUP="${BREW_GROUP:-developer}"
BREW_TEMP_DIR="$BREW_PREFIX/var/homebrew/tmp"

# ── Checks ────────────────────────────────────────────────────────────────────

if [[ $EUID -ne 0 ]]; then
  echo "❌ Must run as root: sudo $0"
  exit 1
fi

if ! dscl . -read /Groups/"$BREW_GROUP" &>/dev/null; then
  echo "❌ Group '$BREW_GROUP' does not exist"
  echo "   Available groups: staff, admin, developer, wheel"
  echo "   Set custom group: sudo BREW_GROUP=staff $0"
  exit 1
fi

if [[ ! -d "$BREW_PREFIX" ]]; then
  echo "❌ Homebrew not found at $BREW_PREFIX"
  echo "   Set custom prefix: sudo BREW_PREFIX=/usr/local $0"
  exit 1
fi

# ── Main Script ───────────────────────────────────────────────────────────────

echo "🔧 Fixing Homebrew permissions (multi-user setup)..."
echo ""
echo "Configuration:"
echo "  Homebrew Prefix: $BREW_PREFIX"
echo "  Group:           $BREW_GROUP"
echo "  Temp Directory:  $BREW_TEMP_DIR"
echo ""

# STEP 1: Remove extended attributes (blocks chmod/chown on macOS)
echo "1️⃣  Removing com.apple.provenance xattr..."
xattr -r -d com.apple.provenance "$BREW_PREFIX" 2>/dev/null || true
echo "   ✅ Done"

# STEP 2: Clean temp directories
echo "2️⃣  Cleaning temp directories..."
rm -rf "$BREW_PREFIX"/var/homebrew/tmp/.cellar/* 2>/dev/null || true
rm -rf /private/tmp/homebrew-unpack* 2>/dev/null || true
rm -rf /private/tmp/d2* 2>/dev/null || true  # Common Homebrew temp pattern
echo "   ✅ Done"

# STEP 3: Fix /private/tmp permissions (sticky bit)
echo "3️⃣  Fixing /private/tmp permissions..."
chmod 1777 /private/tmp
echo "   ✅ Done"

# STEP 4: Create dedicated Homebrew temp directory
echo "4️⃣  Creating dedicated Homebrew temp directory..."
mkdir -p "$BREW_TEMP_DIR"
chown -R root:"$BREW_GROUP" "$BREW_TEMP_DIR"
chmod -R 775 "$BREW_TEMP_DIR"
find "$BREW_TEMP_DIR" -type d -exec chmod g+s {} + 2>/dev/null || true
echo "   ✅ Done"

# STEP 5: Set ownership to root:$BREW_GROUP
echo "5️⃣  Setting ownership to root:$BREW_GROUP..."
chown -R root:"$BREW_GROUP" "$BREW_PREFIX"
echo "   ✅ Done"

# STEP 6: Set permissions (775 + setgid)
echo "6️⃣  Setting permissions (775 + setgid)..."
chmod -R 775 "$BREW_PREFIX"
find "$BREW_PREFIX" -type d -exec chmod g+s {} + 2>/dev/null || true
echo "   ✅ Done"

# STEP 7: Configure system-wide HOMEBREW_TEMP
echo "7️⃣  Configuring system-wide HOMEBREW_TEMP environment variable..."

BREW_TEMP_LINE="export HOMEBREW_TEMP=\"$BREW_TEMP_DIR\""

# /etc/zshrc (primary - all zsh shells, all users)
if ! grep -q "HOMEBREW_TEMP" /etc/zshrc 2>/dev/null; then
  echo "" >> /etc/zshrc
  echo "# Homebrew temp directory (prevents permission conflicts)" >> /etc/zshrc
  echo "$BREW_TEMP_LINE" >> /etc/zshrc
  echo "   ✅ Added to /etc/zshrc"
else
  echo "   ℹ️  Already in /etc/zshrc"
fi

# /etc/bashrc (fallback for bash users)
if [[ ! -f /etc/bashrc ]]; then
  echo "# System-wide bashrc" > /etc/bashrc
fi
if ! grep -q "HOMEBREW_TEMP" /etc/bashrc 2>/dev/null; then
  echo "" >> /etc/bashrc
  echo "# Homebrew temp directory (prevents permission conflicts)" >> /etc/bashrc
  echo "$BREW_TEMP_LINE" >> /etc/bashrc
  echo "   ✅ Added to /etc/bashrc"
else
  echo "   ℹ️  Already in /etc/bashrc"
fi

# /var/root/.zshrc (root user - for 'sudo brew')
if [[ ! -f /var/root/.zshrc ]]; then
  touch /var/root/.zshrc
fi
if ! grep -q "HOMEBREW_TEMP" /var/root/.zshrc 2>/dev/null; then
  echo "" >> /var/root/.zshrc
  echo "# Homebrew temp directory (prevents permission conflicts)" >> /var/root/.zshrc
  echo "$BREW_TEMP_LINE" >> /var/root/.zshrc
  echo "   ✅ Added to /var/root/.zshrc"
else
  echo "   ℹ️  Already in /var/root/.zshrc"
fi

echo ""
echo "✅ Homebrew permissions fixed!"
echo ""
echo "Changes made:"
echo "  • $BREW_PREFIX → root:$BREW_GROUP with group-write"
echo "  • $BREW_TEMP_DIR → dedicated temp directory"
echo "  • HOMEBREW_TEMP → added to /etc/zshrc, /etc/bashrc, /var/root/.zshrc"
echo ""
echo "Next steps:"
echo "  1. Open new Terminal tab (or run: source /etc/zshrc)"
echo "  2. Verify: echo \$HOMEBREW_TEMP"
echo "  3. Run: brew doctor"
echo "  4. Test: brew upgrade"
echo ""
echo "All users in the '$BREW_GROUP' group can now use Homebrew without permission issues."
