# InstallMonitor - Installation Monitoring for InstallBuilder

A comprehensive toolkit to monitor, analyze, and recreate Linux installations with InstallBuilder.

## 🎯 Quick Start

For your **ADMORE2024r0_Linux.tar.gz** file (or any tar.gz with .run installer):

```bash
cd /home/Gagan/work/InstallMonitor
./install_monitor.sh /path/to/ADMORE2024r0_Linux.tar.gz
```

That's it! The tool will automatically:
- ✅ Detect and extract the .run installer
- ✅ Monitor the complete installation
- ✅ Log all files, directories, and environment changes
- ✅ Generate ready-to-use InstallBuilder XML configuration

## 📁 Project Structure

```
InstallMonitor/
├── install_monitor.sh              ← Main tool (use this!)
├── START_HERE.md                   ← Read this first
├── README.md                       ← This file
│
├── scripts/                        ← Specialized monitoring scripts
│   ├── monitor_run_installer.sh    - For .run installers
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

## 🚀 Usage

### Universal Tool (Recommended)

```bash
# Automatically detects installer type
./install_monitor.sh <file_or_directory> [options]
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

## 📊 What You Get

After monitoring, you'll get a timestamped directory with:

| File | Description |
|------|-------------|
| `installbuilder_recipe.txt` | **Main output** - Complete InstallBuilder guide |
| `files_installed.log` | Every file installed with full paths |
| `directories_created.log` | All directories created |
| `environment_changes.log` | PATH, variables, aliases added |
| `installer_output.log` | Complete installer output |
| `install_directory.txt` | Detected installation location |

## 📖 Documentation

1. **[START_HERE.md](START_HERE.md)** - Complete workflow and examples
2. **[docs/QUICK_START.md](docs/QUICK_START.md)** - Quick reference guide
3. **[examples/ADMORE_EXAMPLE.md](examples/ADMORE_EXAMPLE.md)** - Detailed ADMORE example
4. **[docs/README_INSTALL_MONITORING.md](docs/README_INSTALL_MONITORING.md)** - Full technical docs

## 🔧 Features

- **Automatic Detection** - Identifies .run installers, shell scripts, or directories
- **Complete Logging** - Tracks files, directories, environment, processes
- **strace Integration** - Detailed system call monitoring (when available)
- **InstallBuilder Ready** - Generates XML snippets and file mappings
- **Environment Tracking** - PATH, LD_LIBRARY_PATH, aliases, functions
- **Profile Monitoring** - Detects .bashrc, .profile modifications
- **No Guesswork** - Everything documented and logged

## 📝 Examples

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

### View Results
```bash
# Read the InstallBuilder recipe
cat run_install_logs_*/installbuilder_recipe.txt

# See where it installed
cat run_install_logs_*/install_directory.txt

# List all files
cat run_install_logs_*/files_installed.log
```

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
- **tree** - For better directory visualization

## 🔄 Workflow

1. **Monitor Installation**
   ```bash
   ./install_monitor.sh myapp.tar.gz
   ```

2. **Review Recipe**
   ```bash
   cat run_install_logs_*/installbuilder_recipe.txt
   ```

3. **Extract Application Files**
   ```bash
   # Follow instructions in the recipe
   ```

4. **Create InstallBuilder Project**
   ```bash
   mkdir my-installer/files
   cp -r extracted/* my-installer/files/
   ```

5. **Build Installer**
   ```bash
   builder build installer-template.xml
   ```

## 📋 Supported Formats

- ✅ `.tar.gz` containing `.run` installer
- ✅ `.tar.gz` with `install.sh` or `setup.sh`
- ✅ `.tar.bz2` archives
- ✅ Existing installation directories

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

## 📦 Output Directories

Monitoring creates timestamped directories to preserve history:

- `run_install_logs_YYYYMMDD_HHMMSS/` - From .run installers
- `install_logs_YYYYMMDD_HHMMSS/` - From generic monitoring
- `analysis_YYYYMMDD_HHMMSS/` - From existing install analysis

## 🤝 Contributing

This is a utility project. Feel free to:
- Report issues
- Suggest improvements
- Add support for new installer types

## 📄 License

Free to use and modify for your projects.

## 🎓 Learn More

- Read [START_HERE.md](START_HERE.md) for complete workflow
- Check [examples/ADMORE_EXAMPLE.md](examples/ADMORE_EXAMPLE.md) for your use case
- See [docs/QUICK_START.md](docs/QUICK_START.md) for quick reference

---

**Ready to monitor your installation? Just run:**

```bash
./install_monitor.sh ADMORE2024r0_Linux.tar.gz
```

🚀 **Happy building with InstallBuilder!**
