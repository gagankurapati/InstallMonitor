# 🎯 START HERE - Installation Monitoring for InstallBuilder

## For Your ADMORE2024r0_Linux.tar.gz File

### Simplest Way (Recommended) ⭐

```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

This automatically:
- ✅ Detects it contains a .run installer
- ✅ Extracts and monitors everything
- ✅ Generates InstallBuilder recipe
- ✅ Logs all files, directories, and environment changes

### Alternative (More Control)

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz
```

---

## What You Get

After running, you'll have a directory like `run_install_logs_20250125_143022/` containing:

### 📋 Essential Files

1. **`installbuilder_recipe.txt`** ← **START HERE**
   - Complete step-by-step guide
   - Ready-to-use XML snippets
   - Instructions for extracting files

2. **`install_directory.txt`**
   - Where the application installed (e.g., `/opt/admore`)

3. **`files_installed.log`**
   - Every single file that was installed
   - Full paths

4. **`environment_changes.log`**
   - PATH modifications
   - New environment variables
   - Shell profile changes

### 📊 Detailed Logs

- `installation_summary.log` - Complete activity log
- `installer_output.log` - What the installer printed
- `directories_created.log` - All new directories
- `profile_changes.log` - Shell profile modifications
- `strace_output.log` - System calls (if strace installed)

---

## Quick Commands

```bash
# View the main recipe
cat run_install_logs_*/installbuilder_recipe.txt

# See where it installed
cat run_install_logs_*/install_directory.txt

# List all installed files
cat run_install_logs_*/files_installed.log | less

# Check environment changes
cat run_install_logs_*/environment_changes.log
```

---

## Complete Workflow

### 1️⃣ Monitor Installation
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

### 2️⃣ Review Results
```bash
cat run_install_logs_*/installbuilder_recipe.txt
cat run_install_logs_*/install_directory.txt
```

### 3️⃣ Extract Application Files

The .run file contains the real application. Extract it:

```bash
# Method 1: Using installer's extract option
./ADM-2024.0-installer.run --noexec --target=admore_files/

# Method 2: Manual extraction (if Method 1 fails)
SKIP=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' ADM-2024.0-installer.run)
tail -n +$SKIP ADM-2024.0-installer.run | tar xz -C admore_files/
```

### 4️⃣ Create InstallBuilder Project

```bash
# Create project structure
mkdir -p my-admore-installer/files
cd my-admore-installer

# Copy application files
cp -r ../admore_files/* files/

# Or copy from installed location
cp -r /opt/admore/* files/
```

### 5️⃣ Create installer-template.xml

Use the XML snippets from `installbuilder_recipe.txt`:

```xml
<project>
    <shortName>admore</shortName>
    <fullName>ADMORE 2024</fullName>
    <version>2024.0</version>

    <componentList>
        <component>
            <name>default</name>
            <folderList>
                <folder>
                    <destination>${installdir}/bin</destination>
                    <name>binfiles</name>
                </folder>
                <folder>
                    <destination>${installdir}/lib</destination>
                    <name>libfiles</name>
                </folder>
            </folderList>
        </component>
    </componentList>

    <postInstallationActionList>
        <addEnvironmentVariable>
            <name>PATH</name>
            <value>${installdir}/bin:${env(PATH)}</value>
        </addEnvironmentVariable>
    </postInstallationActionList>
</project>
```

### 6️⃣ Build Your Installer

```bash
builder build installer-template.xml
```

### 7️⃣ Test It!

```bash
# Install in a test location
./your-installer.run --prefix=/tmp/test-install

# Verify files
ls -la /tmp/test-install/
```

---

## Tools Available

| Script | Purpose | When to Use |
|--------|---------|-------------|
| **install_monitor.sh** | Universal launcher | **Use this! It's the easiest** |
| monitor_run_installer.sh | For .run installers | When you know you have .run |
| monitor_install.sh | For regular tar.gz | For install.sh scripts |
| analyze_existing_install.sh | Analyze installed app | App already installed |

---

## Common Options

### Silent Installation
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz '--mode unattended --prefix=/opt/admore'
```

### Accept License
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz '--accept-license'
```

### Custom Options
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz '--help'  # See what options exist
```

---

## Troubleshooting

### "Permission denied"
```bash
# Run with sudo if installer needs it
sudo ./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

### Better Monitoring (Recommended)
```bash
# Install strace for detailed tracking
sudo apt-get install strace     # Ubuntu/Debian
sudo yum install strace         # RHEL/CentOS
```

### Can't Find Install Location
```bash
# Check the detection
cat run_install_logs_*/install_directory.txt

# Search manually
find / -name "*admore*" -type d 2>/dev/null
ls -la /opt/
ls -la /usr/local/
```

### Installer Fails
```bash
# Check what went wrong
cat run_install_logs_*/installer_output.log
cat run_install_logs_*/installation_summary.log
```

---

## Need More Help?

### 📚 Documentation Files

1. **[QUICK_START.md](QUICK_START.md)** - Quick reference and cheat sheet
2. **[ADMORE_EXAMPLE.md](ADMORE_EXAMPLE.md)** - Detailed walkthrough for your case
3. **[README_INSTALL_MONITORING.md](README_INSTALL_MONITORING.md)** - Complete documentation

### 🔍 Check Your Logs

All output goes to timestamped directories:
- `run_install_logs_TIMESTAMP/` - from monitoring
- `install_logs_TIMESTAMP/` - from generic monitoring
- `analysis_TIMESTAMP/` - from existing installs

---

## You're Ready! 🚀

Just run:
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

Then follow the recipe in `run_install_logs_*/installbuilder_recipe.txt`

---

**Good luck with your InstallBuilder project!** 🎉
