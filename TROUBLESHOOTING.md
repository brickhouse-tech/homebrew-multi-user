# Troubleshooting Guide

Common issues and their solutions.

## Table of Contents

- [Permission Denied Errors](#permission-denied-errors)
- [HOMEBREW_TEMP Not Set](#homebrew_temp-not-set)
- [User Not in Group](#user-not-in-group)
- [Broken Package Install](#broken-package-install)
- [Git Errors](#git-errors)
- [Still Having Issues](#still-having-issues)

---

## Permission Denied Errors

### Symptom
```
cp: chmod: Operation not permitted
cp: /opt/homebrew/Cellar/package: Permission denied
```

### Diagnosis
```bash
./verify.sh
```

Look for:
- ❌ Not writable by current user
- ❌ User not in group

### Solution 1: Re-run the fix
```bash
sudo ./fix-permissions.sh
```

### Solution 2: Check group membership
```bash
# Check your groups
id -Gn $USER

# You should see "developer" (or your BREW_GROUP)
# If not, add yourself:
sudo dseditgroup -o edit -a $USER -t user developer

# Log out and log back in (required for group changes)
```

### Solution 3: Check directory permissions
```bash
# Should show: drwxrwsr-x root developer
ls -la /opt/homebrew

# Fix if wrong:
sudo chown -R root:developer /opt/homebrew
sudo chmod -R 775 /opt/homebrew
sudo find /opt/homebrew -type d -exec chmod g+s {} +
```

---

## HOMEBREW_TEMP Not Set

### Symptom
```bash
echo $HOMEBREW_TEMP
# (empty output)
```

Or verify.sh shows:
```
❌ Not set
```

### Solution 1: Source shell config
```bash
# For zsh (macOS default):
source /etc/zshrc

# For bash:
source /etc/bashrc

# Then verify:
echo $HOMEBREW_TEMP
# Should show: /opt/homebrew/var/homebrew/tmp
```

### Solution 2: Open new Terminal tab
The variable only loads when a new shell starts. Close your current Terminal tab and open a new one.

### Solution 3: Check config files
```bash
# Should contain: export HOMEBREW_TEMP="/opt/homebrew/var/homebrew/tmp"
grep HOMEBREW_TEMP /etc/zshrc
grep HOMEBREW_TEMP /etc/bashrc

# If missing, re-run:
sudo ./fix-permissions.sh
```

### Solution 4: Manually add to shell config
```bash
# For zsh users:
sudo sh -c 'echo "export HOMEBREW_TEMP=\"/opt/homebrew/var/homebrew/tmp\"" >> /etc/zshrc'

# For bash users:
sudo sh -c 'echo "export HOMEBREW_TEMP=\"/opt/homebrew/var/homebrew/tmp\"" >> /etc/bashrc'

# Then source it:
source /etc/zshrc  # or /etc/bashrc
```

---

## User Not in Group

### Symptom
```
❌ User 'your-username' is NOT in group 'developer'
```

### Solution 1: Add user to group
```bash
# Add yourself to developer group
sudo dseditgroup -o edit -a $USER -t user developer

# Verify:
id -Gn $USER
# Should include "developer"
```

### Solution 2: Log out and log back in
Group membership changes require a fresh login session:
```bash
# Option A: Log out (Apple menu → Log Out)
# Option B: Reboot
sudo reboot
```

### Solution 3: Check group exists
```bash
# List all groups
dscl . -list /Groups

# Should include: developer, staff, admin, wheel

# If "developer" missing, create it:
sudo dscacheutil -group developer

# Or use staff instead:
sudo BREW_GROUP=staff ./fix-permissions.sh
```

---

## Broken Package Install

### Symptom
```
Error: /opt/homebrew/Cellar/package-name is not a directory
Error: /opt/homebrew/Cellar/package-name/1.2.3.reinstall exists
```

### Cause
A previous failed upgrade left temporary files.

### Solution 1: Remove .reinstall directory
```bash
# Replace package-name and version with your actual values:
sudo rm -rf /opt/homebrew/Cellar/package-name/1.2.3.reinstall

# Then retry:
brew upgrade package-name
```

### Solution 2: Force reinstall
```bash
# Uninstall completely
brew uninstall --force package-name

# Clean up any leftover files
sudo rm -rf /opt/homebrew/Cellar/package-name

# Reinstall
brew install package-name
```

### Solution 3: Clean temp directories
```bash
# Remove all temp files
sudo rm -rf /opt/homebrew/var/homebrew/tmp/.cellar/*
sudo rm -rf /private/tmp/homebrew-unpack*
sudo rm -rf /private/tmp/d2*

# Then retry:
brew upgrade
```

---

## Git Errors

### Symptom
```
fatal: not in a git directory
Warning: No remote 'origin' in /opt/homebrew
Error: Command failed with exit 128: git
```

### Cause
Homebrew's internal git repositories have permission issues.

### Solution 1: Fix repository permissions
```bash
# Fix all git repos in Homebrew
sudo find /opt/homebrew -type d -name ".git" -exec chown -R root:developer {} \;
sudo find /opt/homebrew -type d -name ".git" -exec chmod -R 775 {} \;
```

### Solution 2: Update Homebrew
```bash
# Sometimes updating fixes internal git issues
brew update
```

### Solution 3: Re-clone Homebrew core
```bash
# Remove and re-clone core tap
cd /opt/homebrew/Library/Taps/homebrew
sudo rm -rf homebrew-core
brew tap homebrew/core
```

---

## Extended Attributes Blocking Changes

### Symptom
```
chmod: Unable to change file mode on /opt/homebrew/...: Operation not permitted
```

### Cause
macOS adds `com.apple.provenance` xattr to downloaded/mounted files.

### Solution
```bash
# Remove extended attributes
sudo xattr -r -d com.apple.provenance /opt/homebrew

# Then re-run fix:
sudo ./fix-permissions.sh
```

---

## /private/tmp Permission Issues

### Symptom
```
cp: /private/tmp/homebrew-unpack-...: Permission denied
```

### Solution
```bash
# Fix /private/tmp permissions (sticky bit)
sudo chmod 1777 /private/tmp

# Clean old temp files
sudo rm -rf /private/tmp/homebrew-unpack*
sudo rm -rf /private/tmp/d2*
```

---

## Homebrew Doctor Warnings

### Symptom
```bash
brew doctor
# Shows permission warnings
```

### Solution
```bash
# Re-run the fix script
sudo ./fix-permissions.sh

# Then check again:
brew doctor
```

Common warnings and their meaning:
- **"config scripts not in /usr/local"** - Expected on Apple Silicon (uses /opt/homebrew)
- **"Unbrewed files"** - Ignore unless they're causing issues
- **"Permission denied"** - Run fix script

---

## Still Having Issues?

### 1. Run the verification script
```bash
./verify.sh
```

This will tell you exactly what's wrong.

### 2. Check Homebrew diagnostics
```bash
brew config
brew doctor
```

### 3. Check your setup
```bash
# Current user and groups:
id

# Homebrew prefix ownership:
ls -la /opt/homebrew | head -5

# Temp directory:
ls -la /opt/homebrew/var/homebrew/tmp

# Environment variable:
echo $HOMEBREW_TEMP

# Shell config:
grep HOMEBREW_TEMP /etc/zshrc /etc/bashrc /var/root/.zshrc
```

### 4. Start fresh
If nothing works, reset and re-run:

```bash
# Uninstall (see README.md)
sudo sed -i.bak '/HOMEBREW_TEMP/d' /etc/zshrc /etc/bashrc /var/root/.zshrc
sudo rm -rf /opt/homebrew/var/homebrew/tmp

# Re-run fix
sudo ./fix-permissions.sh

# Open new Terminal tab
# Verify
./verify.sh
```

### 5. Report an issue
If you're still stuck:
1. Run `./verify.sh` and save output
2. Run `brew doctor` and save output
3. [Open an issue](https://github.com/brickhouse-tech/homebrew-multi-user/issues) with both outputs

---

## Prevention Tips

### Always use the same group
Don't mix `staff` and `developer`. Pick one and stick with it:
```bash
# Check current group:
ls -la /opt/homebrew | head -1

# If you need to change:
sudo BREW_GROUP=staff ./fix-permissions.sh
```

### Never use sudo brew
Running `brew` with sudo creates root-owned files that break multi-user setups.

**Wrong:**
```bash
sudo brew install package  # ❌
sudo brew upgrade          # ❌
```

**Right:**
```bash
brew install package       # ✅
brew upgrade              # ✅
```

If you accidentally ran `sudo brew`, fix it:
```bash
sudo ./fix-permissions.sh
```

### Keep your group membership
If you change user groups (like removing yourself from `developer`), Homebrew will break again.

Verify you're still in the group:
```bash
id -Gn $USER | grep developer
```

### Use dedicated temp directory
Don't override `HOMEBREW_TEMP` in your personal shell config. The system-wide setting (`/etc/zshrc`) should be the only one.

**Check for conflicts:**
```bash
grep HOMEBREW_TEMP ~/.zshrc ~/.bash_profile ~/.bashrc
# Should be empty (or commented out)
```

---

**Still need help?** [Open an issue](https://github.com/brickhouse-tech/homebrew-multi-user/issues) with:
- Output of `./verify.sh`
- Output of `brew doctor`
- Your macOS version (`sw_vers`)
- Your shell (`echo $SHELL`)
