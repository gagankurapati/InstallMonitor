# How to Monitor ADMORE2024r0_Linux.tar.gz Installation

This guide shows you **exactly** how to use the monitoring tools with your ADMORE installer.

## Your Scenario

You have: `ADMORE2024r0_Linux.tar.gz`

Inside it: `ADM-2024.0-installer.run` (a self-extracting installer)

## Quick Start (Recommended)

### Step 1: Run the specialized .run installer monitor

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz
```

This will:
1. ✅ Extract the tar.gz
2. ✅ Find the ADM-2024.0-installer.run file automatically
3. ✅ Check for installer options (--help, --prefix, etc.)
4. ✅ Run the installer with full monitoring
5. ✅ Track all files, directories, and environment changes
6. ✅ Generate InstallBuilder recipe for you

### Step 2: Review the results

After installation completes, check:

```bash
# Main summary
cat run_install_logs_*/installbuilder_recipe.txt

# What files were installed
cat run_install_logs_*/files_installed.log

# Where it installed
cat run_install_logs_*/install_directory.txt

# Environment changes
cat run_install_logs_*/environment_changes.log
```

## Advanced Usage

### With Silent/Unattended Installation

If the installer supports silent mode:

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz '--mode unattended --prefix=/opt/admore'
```

### With License Acceptance

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz '--accept-license'
```

### Check Installer Options First

If you want to see what options the installer supports before running:

```bash
# Extract manually first
tar -xzf ADMORE2024r0_Linux.tar.gz
cd extracted_folder/

# Try these
./ADM-2024.0-installer.run --help
./ADM-2024.0-installer.run -h
./ADM-2024.0-installer.run --usage
```

Then run with discovered options:

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz '<discovered options>'
```

## What Gets Monitored

### 1. File System Changes
- **All files** created by the installer
- **All directories** created
- Installation location (e.g., /opt/admore, ~/admore, etc.)

### 2. Environment Changes
- PATH modifications
- LD_LIBRARY_PATH additions
- New environment variables
- Shell aliases

### 3. System Calls (with strace)
If `strace` is installed, you get detailed monitoring of:
- Every file opened/created
- Every directory created
- Every command executed
- File permissions changed

Install strace for better monitoring:
```bash
sudo apt-get install strace  # Ubuntu/Debian
sudo yum install strace      # RHEL/CentOS
```

### 4. Shell Profile Changes
- Modifications to ~/.bashrc
- Changes to ~/.bash_profile
- Updates to /etc/profile
- New files in /etc/profile.d/

## Output Files Explained

After running, you'll get a directory like `run_install_logs_20250125_143022/` with:

| File | What it contains |
|------|------------------|
| `installbuilder_recipe.txt` | **START HERE** - Complete guide for recreating with InstallBuilder |
| `installation_summary.log` | Main log with all activities |
| `installer_output.log` | Complete output from the ADM installer |
| `files_installed.log` | Every file installed (full paths) |
| `directories_created.log` | Every directory created |
| `environment_changes.log` | Before/after environment comparison |
| `profile_changes.log` | Shell profile modifications |
| `strace_output.log` | Detailed system calls (if strace available) |
| `install_directory.txt` | Detected installation directory |

## Step-by-Step InstallBuilder Recreation

### 1. Extract the Real Application Files

The .run file contains the actual application files. Extract them:

**Method A: Using the installer's extract option (try first)**
```bash
./ADM-2024.0-installer.run --noexec --target=admore_extracted/
```

**Method B: Manual extraction**
```bash
# Find where the embedded archive starts
SKIP=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' ADM-2024.0-installer.run)

# Extract it
tail -n +$SKIP ADM-2024.0-installer.run | tar xz
```

### 2. Analyze What Got Installed

Use the logs from monitoring:

```bash
# See installation structure
cat run_install_logs_*/directories_created.log | head -20

# Common patterns:
# /opt/admore/bin           -> Executables
# /opt/admore/lib           -> Libraries
# /opt/admore/share         -> Data files
# /opt/admore/doc           -> Documentation
```

### 3. Create InstallBuilder Project Structure

```
your-installbuilder-project/
├── installer-template.xml
└── files/
    ├── bin/           <- Copy executables here
    ├── lib/           <- Copy libraries here
    ├── share/         <- Copy data files here
    └── doc/           <- Copy docs here
```

Copy files from extracted .run or from the installed location:

```bash
# If you extracted the .run contents
cp -r admore_extracted/* your-installbuilder-project/files/

# OR if analyzing an existing installation
cp -r /opt/admore/* your-installbuilder-project/files/
```

### 4. Update installer-template.xml

Use the XML snippets from `installbuilder_recipe.txt`:

```xml
<project>
    <shortName>admore</shortName>
    <fullName>ADMORE 2024</fullName>
    <version>2024.0</version>

    <componentList>
        <component>
            <name>default</name>
            <description>ADMORE Application</description>
            <canBeEdited>0</canBeEdited>
            <folderList>
                <!-- Executables -->
                <folder>
                    <description>Program Executables</description>
                    <destination>${installdir}/bin</destination>
                    <name>binfiles</name>
                    <platforms>all</platforms>
                </folder>

                <!-- Libraries -->
                <folder>
                    <description>Libraries</description>
                    <destination>${installdir}/lib</destination>
                    <name>libfiles</name>
                    <platforms>all</platforms>
                </folder>

                <!-- Data files -->
                <folder>
                    <description>Application Data</description>
                    <destination>${installdir}/share</destination>
                    <name>datafiles</name>
                    <platforms>all</platforms>
                </folder>
            </folderList>
        </component>
    </componentList>

    <!-- Environment setup from monitoring logs -->
    <postInstallationActionList>
        <addEnvironmentVariable>
            <name>PATH</name>
            <scope>system</scope>
            <value>${installdir}/bin:${env(PATH)}</value>
        </addEnvironmentVariable>

        <addEnvironmentVariable>
            <name>LD_LIBRARY_PATH</name>
            <scope>system</scope>
            <value>${installdir}/lib:${env(LD_LIBRARY_PATH)}</value>
        </addEnvironmentVariable>
    </postInstallationActionList>
</project>
```

### 5. Build Your Installer

```bash
cd your-installbuilder-project
/path/to/installbuilder/bin/builder build installer-template.xml
```

## Troubleshooting

### Issue: "No .run file found in tarball"

**Solution:** The tarball might use different compression. Try:
```bash
tar -xjf ADMORE2024r0_Linux.tar.gz  # for bzip2
tar -xf ADMORE2024r0_Linux.tar.gz   # auto-detect
```

### Issue: "Permission denied" when running installer

**Solution:** The script automatically makes it executable, but if needed:
```bash
chmod +x ADM-2024.0-installer.run
```

### Issue: Installer asks for sudo password

**Solution:** Run the monitoring script with sudo:
```bash
sudo ./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz
```

### Issue: Can't find where files were installed

**Solution:** Check multiple places:
```bash
# From monitoring logs
cat run_install_logs_*/install_directory.txt

# Common install locations
ls -la /opt/
ls -la /usr/local/
ls -la ~/

# Search for specific files from installer output
find / -name "admore" -type d 2>/dev/null
```

### Issue: Installer runs but monitoring misses files

**Solution:** Make sure strace is installed for better tracking:
```bash
sudo apt-get install strace
# Then re-run monitoring
```

## Complete Example Session

Here's what a complete session looks like:

```bash
# 1. Run monitoring
$ ./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz

╔════════════════════════════════════════════════════════╗
║     .RUN Installer Monitor for InstallBuilder          ║
╚════════════════════════════════════════════════════════╝

[2025-01-25 14:30:22] Starting .run installer monitoring...
[2025-01-25 14:30:22] Log directory: run_install_logs_20250125_143022

========================================
EXTRACTING TARBALL
========================================
[2025-01-25 14:30:23] Tarball: ADMORE2024r0_Linux.tar.gz
[2025-01-25 14:30:23] Size: 450M
[2025-01-25 14:30:25] Extraction complete
[2025-01-25 14:30:25] Found: /path/to/ADM-2024.0-installer.run

========================================
INSTALLER OPTIONS
========================================
[2025-01-25 14:30:26] Checking for help/usage information...
[2025-01-25 14:30:26] Found installer options:
  --prefix <path>        Installation directory
  --mode unattended      Silent installation
  --accept-license       Accept license agreement

No installer options provided.
Press Enter to run installer interactively, or Ctrl+C to abort
Continue? (y/N) y

========================================
RUNNING INSTALLER WITH MONITORING
========================================
[2025-01-25 14:30:30] Using strace for detailed monitoring
[2025-01-25 14:30:30] Install command: ./ADM-2024.0-installer.run
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Installing ADMORE 2024.0...
[Installation progress...]
Installation complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[2025-01-25 14:35:45] Installer completed successfully

========================================
ANALYZING INSTALLATION CHANGES
========================================
[2025-01-25 14:35:48] New files detected: 1247
[2025-01-25 14:35:49] Primary installation directory: /opt/admore

========================================
GENERATING INSTALLBUILDER RECIPE
========================================
[2025-01-25 14:35:50] Recipe generated

========================================
SUMMARY
========================================
Installation Monitoring Complete

Next Steps:
  1. Read: run_install_logs_20250125_143022/installbuilder_recipe.txt
  2. Extract contents from the .run file
  3. Copy files to InstallBuilder project
  4. Build and test your installer

[2025-01-25 14:35:51] ✓ Monitoring complete!

# 2. Review results
$ cat run_install_logs_20250125_143022/installbuilder_recipe.txt
[... detailed InstallBuilder guide ...]

# 3. Check what was installed
$ cat run_install_logs_20250125_143022/install_directory.txt
/opt/admore

# 4. Copy to InstallBuilder project
$ mkdir -p my-admore-installer/files
$ cp -r /opt/admore/* my-admore-installer/files/

# 5. Build installer
$ builder build my-admore-installer/installer-template.xml
```

## Quick Reference

| Task | Command |
|------|---------|
| Monitor installation | `./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz` |
| With options | `./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz '--mode unattended'` |
| View recipe | `cat run_install_logs_*/installbuilder_recipe.txt` |
| Check install location | `cat run_install_logs_*/install_directory.txt` |
| See all files | `cat run_install_logs_*/files_installed.log` |
| Environment changes | `cat run_install_logs_*/environment_changes.log` |

## Need Help?

1. Check `run_install_logs_*/installation_summary.log` for complete details
2. Review `run_install_logs_*/installer_output.log` for installer messages
3. If strace is available, check `run_install_logs_*/strace_output.log`

---

**You're all set! Just run the command and follow the generated recipe.**
