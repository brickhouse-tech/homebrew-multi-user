#!/bin/bash
# verify.sh - Verify Homebrew multi-user setup
# https://github.com/brickhouse-tech/homebrew-multi-user

set -e

BREW_PREFIX="${BREW_PREFIX:-/opt/homebrew}"
BREW_TEMP_DIR="$BREW_PREFIX/var/homebrew/tmp"

echo "🔍 Verifying Homebrew multi-user setup..."
echo ""

ERRORS=0
WARNINGS=0

# ── Check 1: HOMEBREW_TEMP environment variable ───────────────────────────────

echo "1️⃣  Checking HOMEBREW_TEMP environment variable..."
if [[ -n "$HOMEBREW_TEMP" ]]; then
  echo "   ✅ Set to: $HOMEBREW_TEMP"
  if [[ "$HOMEBREW_TEMP" != "$BREW_TEMP_DIR" ]]; then
    echo "   ⚠️  Warning: Expected $BREW_TEMP_DIR"
    ((WARNINGS++))
  fi
else
  echo "   ❌ Not set"
  echo "      Open a new Terminal tab or run: source /etc/zshrc"
  ((ERRORS++))
fi

# ── Check 2: Temp directory exists and is writable ────────────────────────────

echo "2️⃣  Checking temp directory..."
if [[ -d "$BREW_TEMP_DIR" ]]; then
  echo "   ✅ Exists: $BREW_TEMP_DIR"
  
  # Check ownership
  OWNER=$(stat -f "%u:%g" "$BREW_TEMP_DIR")
  echo "   ℹ️  Owner: $OWNER"
  
  # Check permissions
  PERMS=$(stat -f "%Sp" "$BREW_TEMP_DIR")
  echo "   ℹ️  Permissions: $PERMS"
  
  # Test write access
  if touch "$BREW_TEMP_DIR/.test-write" 2>/dev/null; then
    rm "$BREW_TEMP_DIR/.test-write"
    echo "   ✅ Writable"
  else
    echo "   ❌ Not writable by current user"
    ((ERRORS++))
  fi
else
  echo "   ❌ Not found: $BREW_TEMP_DIR"
  ((ERRORS++))
fi

# ── Check 3: Homebrew prefix ownership ────────────────────────────────────────

echo "3️⃣  Checking Homebrew prefix ownership..."
if [[ -d "$BREW_PREFIX" ]]; then
  OWNER=$(stat -f "%Su:%Sg" "$BREW_PREFIX")
  echo "   ℹ️  Owner: $OWNER"
  
  # Check if group-writable
  PERMS=$(stat -f "%Sp" "$BREW_PREFIX")
  if [[ "$PERMS" =~ ^drwxrw ]]; then
    echo "   ✅ Group-writable"
  else
    echo "   ⚠️  Warning: Not group-writable ($PERMS)"
    ((WARNINGS++))
  fi
else
  echo "   ❌ Homebrew not found at $BREW_PREFIX"
  ((ERRORS++))
fi

# ── Check 4: User is in the correct group ─────────────────────────────────────

echo "4️⃣  Checking user group membership..."
BREW_GROUP=$(stat -f "%Sg" "$BREW_PREFIX")
CURRENT_USER=$(whoami)
USER_GROUPS=$(id -Gn "$CURRENT_USER")

if echo "$USER_GROUPS" | grep -q "$BREW_GROUP"; then
  echo "   ✅ User '$CURRENT_USER' is in group '$BREW_GROUP'"
else
  echo "   ❌ User '$CURRENT_USER' is NOT in group '$BREW_GROUP'"
  echo "      Current groups: $USER_GROUPS"
  echo "      Add with: sudo dseditgroup -o edit -a $CURRENT_USER -t user $BREW_GROUP"
  ((ERRORS++))
fi

# ── Check 5: Shell config files ───────────────────────────────────────────────

echo "5️⃣  Checking shell config files..."

if grep -q "HOMEBREW_TEMP" /etc/zshrc 2>/dev/null; then
  echo "   ✅ /etc/zshrc configured"
else
  echo "   ⚠️  /etc/zshrc not configured"
  ((WARNINGS++))
fi

if grep -q "HOMEBREW_TEMP" /etc/bashrc 2>/dev/null; then
  echo "   ✅ /etc/bashrc configured"
else
  echo "   ℹ️  /etc/bashrc not configured (optional)"
fi

if grep -q "HOMEBREW_TEMP" /var/root/.zshrc 2>/dev/null; then
  echo "   ✅ /var/root/.zshrc configured"
else
  echo "   ⚠️  /var/root/.zshrc not configured"
  ((WARNINGS++))
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo "✅ All checks passed!"
  echo ""
  echo "Your Homebrew multi-user setup is working correctly."
  exit 0
elif [[ $ERRORS -eq 0 ]]; then
  echo "⚠️  $WARNINGS warning(s) found"
  echo ""
  echo "Setup is mostly working but has minor issues."
  exit 0
else
  echo "❌ $ERRORS error(s), $WARNINGS warning(s) found"
  echo ""
  echo "Run: sudo ./fix-permissions.sh"
  exit 1
fi
