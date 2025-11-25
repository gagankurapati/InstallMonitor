# Quick Start - Installation Monitoring for InstallBuilder

## For Your ADMORE Case 🎯

You have: `ADMORE2024r0_Linux.tar.gz` containing `ADM-2024.0-installer.run`

**Just run this:**

```bash
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz
```

That's it! ✅

---

## What Happens Next

1. **Automatic extraction** - Finds and extracts the .run file
2. **Options detection** - Checks what installer options are available
3. **Full monitoring** - Runs installer and tracks everything
4. **Analysis** - Detects all files, directories, environment changes
5. **Recipe generation** - Creates InstallBuilder configuration for you

**Output:** `run_install_logs_TIMESTAMP/` directory with everything you need

---

## Key Files to Check

```bash
# 📋 Start here - complete guide
cat run_install_logs_*/installbuilder_recipe.txt

# 📁 Where files were installed
cat run_install_logs_*/install_directory.txt

# 📄 Complete file list
cat run_install_logs_*/files_installed.log

# 🌍 Environment changes (PATH, etc.)
cat run_install_logs_*/environment_changes.log
```

---

## All Available Tools

| Tool | Use When | Command |
|------|----------|---------|
| **monitor_run_installer.sh** | You have .tar.gz with .run inside | `./monitor_run_installer.sh file.tar.gz` |
| **monitor_install.sh** | You have .tar.gz with install.sh | `./monitor_install.sh file.tar.gz` |
| **analyze_existing_install.sh** | App already installed | `./analyze_existing_install.sh /opt/app` |

---

## Installation Monitoring Cheat Sheet

### Basic Usage
```bash
# .run installer (like ADMORE)
./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz

# Regular tar.gz with install script
./monitor_install.sh myapp.tar.gz

# Already installed app
./analyze_existing_install.sh /opt/myapp
```

### With Options
```bash
# Silent installation
./monitor_run_installer.sh app.tar.gz '--mode unattended --prefix=/opt/app'

# Accept license automatically
./monitor_run_installer.sh app.tar.gz '--accept-license'

# Custom install command
./monitor_install.sh app.tar.gz 'bash setup.sh --install-dir=$HOME/apps'
```

### After Monitoring
```bash
# View main summary
cat */installation_summary.log

# Check InstallBuilder recipe
cat */installbuilder_recipe.txt

# See what files were installed
cat */files_installed.log | less

# Check environment changes
cat */environment_changes.log
```

---

## Next Steps After Monitoring

1. **Read the recipe**
   ```bash
   cat run_install_logs_*/installbuilder_recipe.txt
   ```

2. **Extract application files from .run**
   ```bash
   ./ADM-2024.0-installer.run --noexec --target=extracted/
   ```

3. **Copy to InstallBuilder project**
   ```bash
   cp -r extracted/* /path/to/installbuilder/project/files/
   ```

4. **Update installer-template.xml**
   - Use XML snippets from recipe
   - Add file components
   - Add environment variables

5. **Build and test**
   ```bash
   builder build installer-template.xml
   ```

---

## Detailed Documentation

- 📖 **[ADMORE_EXAMPLE.md](ADMORE_EXAMPLE.md)** - Complete walkthrough for your specific case
- 📖 **[README_INSTALL_MONITORING.md](README_INSTALL_MONITORING.md)** - Full documentation for all tools

---

## Troubleshooting

**Installer asks for sudo:**
```bash
sudo ./monitor_run_installer.sh ADMORE2024r0_Linux.tar.gz
```

**Better monitoring (install strace):**
```bash
sudo apt-get install strace  # Ubuntu/Debian
sudo yum install strace      # RHEL/CentOS
```

**Can't find install location:**
```bash
cat run_install_logs_*/install_directory.txt
find / -name "*admore*" -type d 2>/dev/null
```

---

**🚀 You're ready! Just run the command above and follow the generated recipe.**
