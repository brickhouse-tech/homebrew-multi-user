# Homebrew Multi-User Setup

**Fix Homebrew permission issues on multi-user macOS systems.**

## The Problem

Homebrew is designed for single-user installations. On multi-user Macs (shared workstations, families, Mac Minis, CI machines), you'll hit permission errors like:

```
cp: chmod: Operation not permitted
cp: /opt/homebrew/Cellar/package-name: Permission denied
Error: /opt/homebrew/Cellar/package-name is not a directory
```

**Root cause:** Homebrew uses `/private/tmp` for temporary files during upgrades. Whoever runs `brew upgrade` first (root or user) owns those temp files, causing permission conflicts for other users.

## The Solution

This script fixes Homebrew permissions permanently by:

1. ✅ Setting proper ownership (`root:developer` with group-write enabled)
2. ✅ Creating a dedicated temp directory (`/opt/homebrew/var/homebrew/tmp`)
3. ✅ Configuring `HOMEBREW_TEMP` system-wide (all users, all shells)
4. ✅ Fixing extended attributes that block permission changes (macOS quirk)

**After running this script:**
- All users in the `developer` (or `staff`) group can use Homebrew
- No more `sudo brew` hacks
- No more permission-denied errors
- Terminal tabs and subshells work correctly

## Who This Is For

- ✅ Multi-user Macs (families, shared workstations)
- ✅ Mac Mini build/CI machines
- ✅ Teams sharing a development Mac
- ✅ Anyone tired of Homebrew permission issues

## Why Not Install Homebrew in $HOME?

**TL;DR:** Installing Homebrew in your home directory (`~/homebrew`) makes installs **10-100x slower**.

### The Performance Problem

Homebrew provides pre-compiled binaries called **"bottles"** for popular packages. When you run `brew install nodejs`, Homebrew downloads a ready-to-use binary instead of compiling from source.

**Bottles only work with standard install locations:**
- `/opt/homebrew` (Apple Silicon)
- `/usr/local` (Intel Mac)

> **From Homebrew's official docs:**
>
> "This prefix is required for most bottles (binary packages) to be used. Many things will need to be built from source outside the default prefix."
>
> — [Homebrew Installation Docs](https://docs.brew.sh/Installation)

**What this means in practice:**

| Install Location | Install Method | Speed |
|-----------------|---------------|-------|
| `/opt/homebrew` (standard) | Pre-compiled bottles | ⚡ **Fast** (seconds) |
| `~/homebrew` (home directory) | Compile from source | 🐌 **Slow** (minutes to hours) |

**Real-world example:**
```bash
# Standard location (/opt/homebrew)
brew install nodejs
# Downloads 25MB binary, installs in 5 seconds ✅

# Home directory (~/homebrew)
brew install nodejs
# Compiles from source, takes 15+ minutes 😱
```

### Why Bottles Don't Work Outside Standard Locations

Bottles are pre-compiled for specific paths. From [Homebrew Bottles Docs](https://docs.brew.sh/Bottles):

> "Bottles will not be used if the bottle's cellar is neither `:any` (it requires being installed to a specific Cellar path) nor equal to the current `HOMEBREW_CELLAR` (the required Cellar path does not match that of the current Homebrew installation)."

**Translation:** Most bottles are hardcoded for `/opt/homebrew` or `/usr/local`. Installing elsewhere forces source compilation.

### The Multi-User Trap

This is why many people **mistakenly** install Homebrew in their home directory:

1. ❌ Install to `/opt/homebrew` → hit permission errors with other users
2. ❌ Give up and reinstall to `~/homebrew` → "fixes" permissions
3. 😱 Everything now takes forever to install
4. 🤔 Eventually Google "why is homebrew so slow"

**The right solution:** Fix permissions on `/opt/homebrew` instead (this repo).

### Performance Impact

Compiling from source for a typical development setup:

| Package | Bottle (seconds) | Source (minutes) |
|---------|-----------------|------------------|
| node | 5s | 15m |
| python@3.12 | 8s | 25m |
| postgresql | 10s | 45m |
| gcc | 15s | **2+ hours** |

**Installing 20 packages:**
- Standard location: ~5 minutes
- Home directory: **3+ hours** (or fails entirely if you hit compilation errors)

### Additional Problems with Home Directory Install

Beyond performance:
- ❌ No bottles = hit every compilation dependency issue
- ❌ Build failures (missing headers, compiler quirks)
- ❌ Non-standard paths break some installers
- ❌ Harder to get help (Homebrew maintainers assume standard prefix)
- ❌ Still doesn't solve multi-user access (only YOU can use it)

### The Right Approach

✅ **Install Homebrew to the standard location** (`/opt/homebrew`)
✅ **Fix permissions** (this repo) so multiple users can use it
✅ **Get bottles** = fast installs
✅ **Everyone's happy** 🎉

This is exactly why this repo exists: to fix multi-user permissions **without** sacrificing performance.

## Quick Start

### 1. Run the Fix

```bash
# Clone the repo
git clone https://github.com/brickhouse-tech/homebrew-multi-user.git
cd homebrew-multi-user

# Run the fix (requires sudo)
sudo ./fix-permissions.sh
```

**Custom group:**
```bash
sudo BREW_GROUP=staff ./fix-permissions.sh
```

### 2. Verify It Worked

```bash
# Open a new Terminal tab, then:
./verify.sh
```

Should show:
```
✅ All checks passed!
Your Homebrew multi-user setup is working correctly.
```

### 3. Test It

```bash
# Check environment variable
echo $HOMEBREW_TEMP
# Should show: /opt/homebrew/var/homebrew/tmp

# Run Homebrew doctor
brew doctor

# Test an upgrade
brew upgrade
```

## What It Does

### Permissions & Ownership
- Sets `/opt/homebrew` ownership to `root:developer` (or custom group)
- Enables group-write permissions (775)
- Applies setgid bit so new files inherit group ownership

### Temp Directory
- Creates `/opt/homebrew/var/homebrew/tmp`
- Cleans old temp directories in `/private/tmp`
- Sets `HOMEBREW_TEMP` environment variable system-wide

### Shell Configuration
Adds `export HOMEBREW_TEMP="/opt/homebrew/var/homebrew/tmp"` to:
- `/etc/zshrc` (all zsh users, all shells)
- `/etc/bashrc` (bash users)
- `/var/root/.zshrc` (handles `sudo brew` edge case)

## Configuration

### Custom Group

Default group is `developer`. Use `staff` or another group if needed:

```bash
sudo BREW_GROUP=staff ./fix-permissions.sh
```

**Available groups on macOS:**
- `staff` - default for regular users
- `developer` - for Xcode/dev tools users
- `admin` - for admin users
- `wheel` - for sudo users

Check your groups:
```bash
id -Gn $USER
```

Add yourself to a group:
```bash
sudo dseditgroup -o edit -a $USER -t user developer
```

### Custom Homebrew Prefix

If you use `/usr/local` instead of `/opt/homebrew`:

```bash
sudo BREW_PREFIX=/usr/local ./fix-permissions.sh
```

## Troubleshooting

### "Not writable by current user"

**Cause:** You're not in the group that owns Homebrew.

**Fix:**
```bash
# Check current groups
id -Gn $USER

# Add yourself to the developer group
sudo dseditgroup -o edit -a $USER -t user developer

# Log out and log back in (or reboot)
```

### "HOMEBREW_TEMP not set"

**Cause:** Shell config not loaded.

**Fix:**
```bash
# Open a new Terminal tab, or:
source /etc/zshrc

# Verify:
echo $HOMEBREW_TEMP
```

### "Command failed with exit 128: git"

**Cause:** Homebrew's internal git repos have permission issues.

**Fix:**
```bash
# Re-run the fix
sudo ./fix-permissions.sh

# Clean Homebrew cache
rm -rf ~/Library/Caches/Homebrew/*
```

### Still having issues?

Run the verification script:
```bash
./verify.sh
```

It will tell you exactly what's wrong.

## How It Works

### The Permission Problem

macOS uses Unix permissions:
- **Owner** - single user (e.g., `nem`)
- **Group** - multiple users (e.g., `developer`)
- **Others** - everyone else

Homebrew defaults to:
- Owner: whoever installed it
- Group: their primary group (`staff`)
- Permissions: 755 (owner-writable only)

**Result:** Other users can't write to Homebrew directories.

### The Temp Directory Problem

During `brew upgrade`, Homebrew:
1. Downloads new package to `/private/tmp/homebrew-unpack-...`
2. Unpacks to `/opt/homebrew/Cellar/package/.reinstall`
3. Moves `.reinstall` to final location

**Problem:** If temp files are owned by root, regular users can't delete them.

### The Solution

1. **Ownership:** `root:developer` (root owns, group can write)
2. **Permissions:** 775 (owner+group writable)
3. **Setgid bit:** New files inherit group ownership
4. **Dedicated temp:** `HOMEBREW_TEMP` points to group-writable location

## Why Not Just `sudo brew`?

**Don't do it.** Running `brew` with sudo causes:
- ❌ Files owned by root (breaks future non-sudo runs)
- ❌ Security risk (Homebrew scripts run as root)
- ❌ Homebrew complains and warns against it
- ❌ Doesn't solve the underlying problem

**Proper fix:** This script.

## Uninstall

To revert to single-user Homebrew:

```bash
# Remove HOMEBREW_TEMP from shell configs
sudo sed -i.bak '/HOMEBREW_TEMP/d' /etc/zshrc /etc/bashrc /var/root/.zshrc

# Reset ownership to your user
sudo chown -R $USER:staff /opt/homebrew

# Remove dedicated temp directory
sudo rm -rf /opt/homebrew/var/homebrew/tmp
```

## Technical Details

### macOS Shell Loading Order

**Zsh (default since macOS Catalina):**
1. `/etc/zprofile` - system-wide, login only
2. `~/.zprofile` - user-specific, login only
3. `/etc/zshrc` - **system-wide, all shells** ← we use this
4. `~/.zshrc` - user-specific, all shells

**Bash:**
1. `/etc/profile` - system-wide, login only
2. `~/.bash_profile` - user-specific
3. `/etc/bashrc` - system-wide ← we use this

**Why `/etc/zshrc`?**
- Terminal tabs spawn **non-login shells** (skip `/etc/zprofile`)
- Every new tab/window runs `/etc/zshrc`
- Subshells and scripts inherit the variable

### Extended Attributes

macOS adds `com.apple.provenance` xattr to files from disk images and downloads. This blocks `chmod`/`chown` operations.

The script removes it first:
```bash
xattr -r -d com.apple.provenance /opt/homebrew
```

### Setgid Bit

The `g+s` (setgid) bit on directories makes new files inherit the directory's group:

```bash
chmod g+s /opt/homebrew  # Enable setgid
```

**Result:** When user A creates a file in `/opt/homebrew`, it's owned by `user-a:developer` (not `user-a:staff`), so user B (also in `developer`) can modify it.

## Contributing

Found a bug? Have a suggestion? [Open an issue](https://github.com/brickhouse-tech/homebrew-multi-user/issues) or submit a PR.

## License

MIT License - see [LICENSE](LICENSE) for details.

## Credits

Built by [Brickhouse Tech](https://github.com/brickhouse-tech) to solve real multi-user Homebrew pain.

**Maintained by:** TARS

## See Also

- [Homebrew Documentation](https://docs.brew.sh/)
- [macOS File Permissions Guide](https://support.apple.com/guide/terminal/file-permissions-apdd100908f-06b3-4e63-8a87-32e71241bab4/mac)
- [Unix File Permissions Explained](https://en.wikipedia.org/wiki/File-system_permissions#Notation_of_traditional_Unix_permissions)
