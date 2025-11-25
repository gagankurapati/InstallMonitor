# InstallMonitor - Installation Monitoring for InstallBuilder

A comprehensive toolkit to monitor, analyze, and recreate Linux installations with InstallBuilder.

## 🎯 Quick Start

For **ADMORE2024r0_Linux.tar.gz** (or any tar.gz with .run installer):

```bash
cd /home/Gagan/work/InstallMonitor
./install_monitor.sh /path/to/ADMORE2024r0_Linux.tar.gz
```

That's it! The tool will automatically:
- ✅ Detect and extract the .run installer
- ✅ Monitor the complete installation
- ✅ Log all files, directories, and environment changes
- ✅ Generate ready-to-use InstallBuilder XML configuration

---

## 📁 Project Structure

```
InstallMonitor/
├── install_monitor.sh              ← Main tool (use this!)
├── README.md                       ← This file
│
├── scripts/                        ← Specialized monitoring tools
│   ├── monitor_run_installer.sh    - For .run installers (ADMORE)
│   ├── monitor_install.sh          - For regular tar.gz
│   └── analyze_existing_install.sh - For installed apps
│
├── docs/                           ← Documentation
│   ├── QUICK_START.md              - Quick reference
│   └── README_INSTALL_MONITORING.md - Full documentation
│
└── examples/                       ← Examples and tutorials
    └── ADMORE_EXAMPLE.md           - Complete ADMORE walkthrough
```

---

## 🚀 Usage

### Main Tool (Recommended)

```bash
# Automatically detects installer type
./install_monitor.sh <file_or_directory> [options]

# Examples
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
./install_monitor.sh app.tar.gz '--mode unattended'
./install_monitor.sh /opt/installed-app
```

### Specialized Tools

```bash
# For .run installers (like ADMORE)
./scripts/monitor_run_installer.sh myapp.tar.gz

# For tar.gz with install.sh
./scripts/monitor_install.sh myapp.tar.gz

# Analyze already-installed app
./scripts/analyze_existing_install.sh /opt/myapp
```

---

## 📊 What You Get

After monitoring, you'll get a timestamped directory with:

### Essential Files

| File | Description |
|------|-------------|
| `installbuilder_recipe.txt` | **START HERE** - Complete InstallBuilder guide |
| `files_installed.log` | Every file installed with full paths |
| `directories_created.log` | All directories created |
| `environment_changes.log` | PATH, variables, aliases added |
| `installer_output.log` | Complete installer output |
| `install_directory.txt` | Detected installation location |
| `strace_output.log` | System calls (if strace available) |

### Quick Commands

```bash
# View the InstallBuilder recipe
cat run_install_logs_*/installbuilder_recipe.txt

# See where it installed
cat run_install_logs_*/install_directory.txt

# List all installed files
cat run_install_logs_*/files_installed.log

# Check environment changes
cat run_install_logs_*/environment_changes.log
```

---

## 📝 Complete Workflow

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
# OR copy from installed location
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

### 6️⃣ Build and Test

```bash
builder build installer-template.xml
./your-installer.run --prefix=/tmp/test-install
```

---

## 🔧 Features

- **Automatic Detection** - Identifies .run installers, shell scripts, or directories
- **Complete Logging** - Tracks files, directories, environment, processes
- **strace Integration** - Detailed system call monitoring (when available)
- **InstallBuilder Ready** - Generates XML snippets and file mappings
- **Environment Tracking** - PATH, LD_LIBRARY_PATH, aliases, functions
- **Profile Monitoring** - Detects .bashrc, .profile modifications
- **No Guesswork** - Everything documented and logged

---

## 📋 Supported Formats

- ✅ `.tar.gz` containing `.run` installer
- ✅ `.tar.gz` with `install.sh` or `setup.sh`
- ✅ `.tar.bz2` archives
- ✅ Existing installation directories

---

## 🛠️ Requirements

### Required
- bash 4.0+
- tar
- Standard Unix tools (find, grep, awk, sed)

### Optional (Recommended)
- **strace** - For detailed system call monitoring
  ```bash
  sudo apt-get install strace  # Ubuntu/Debian
  sudo yum install strace      # RHEL/CentOS
  ```

---

## 🐛 Troubleshooting

### Permission Denied
```bash
# Run with sudo if installer requires root
sudo ./install_monitor.sh myapp.tar.gz
```

### Better Monitoring
```bash
# Install strace for detailed tracking
sudo apt-get install strace
```

### Can't Find Installation
```bash
# Check detected location
cat run_install_logs_*/install_directory.txt

# Search manually
find / -name "*myapp*" -type d 2>/dev/null
```

---

## 📖 Documentation

- **[docs/QUICK_START.md](docs/QUICK_START.md)** - Quick reference guide
- **[examples/ADMORE_EXAMPLE.md](examples/ADMORE_EXAMPLE.md)** - Complete ADMORE walkthrough
- **[docs/README_INSTALL_MONITORING.md](docs/README_INSTALL_MONITORING.md)** - Full technical documentation

---

## 📦 Output Directories

Monitoring creates timestamped directories to preserve history:

- `run_install_logs_YYYYMMDD_HHMMSS/` - From .run installers
- `install_logs_YYYYMMDD_HHMMSS/` - From generic monitoring
- `analysis_YYYYMMDD_HHMMSS/` - From existing install analysis

---

## 📄 License

Free to use and modify for your projects.

---

## 🎓 Examples

### Monitor ADMORE Installation
```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

### With Silent Installation
```bash
./install_monitor.sh app.tar.gz '--mode unattended --prefix=/opt/app'
```

### Analyze Existing Installation
```bash
./install_monitor.sh /opt/installed-app
```

---

**Ready to monitor your installation?**

```bash
cd /home/Gagan/work/InstallMonitor
./install_monitor.sh /path/to/ADMORE2024r0_Linux.tar.gz
```

🚀 **Happy building with InstallBuilder!**
