# Installation Monitoring Tools for InstallBuilder

This toolkit helps you monitor and log all activities from tar.gz installations so you can recreate them with InstallBuilder.

## Tools Included

### 1. monitor_install.sh - Full Installation Monitor
**Use when:** You need to install a tar.gz and capture everything it does

**What it captures:**
- All files extracted and installed
- Directories created
- Environment variable changes (PATH, LD_LIBRARY_PATH, etc.)
- Shell aliases and functions added
- Profile file modifications (.bashrc, .bash_profile, etc.)
- Process execution during installation
- Complete before/after filesystem snapshots

**Usage:**
```bash
# Automatic detection of install script
./monitor_install.sh myapp.tar.gz

# With specific install command
./monitor_install.sh myapp.tar.gz './install.sh'
./monitor_install.sh myapp.tar.gz 'bash setup.sh --prefix=/opt/myapp'
```

**Output:**
Creates a timestamped directory `install_logs_YYYYMMDD_HHMMSS/` containing:
- `installation_summary.log` - Main log with all activities
- `files_installed.log` - Complete list of new files
- `directories_created.log` - All new directories
- `environment_changes.log` - Environment variable changes
- `profile_modifications.log` - Changes to shell profiles
- `installbuilder_recipe.txt` - **Ready-to-use InstallBuilder configuration**

### 2. analyze_existing_install.sh - Analyze Existing Installation
**Use when:** The application is already installed and you want to analyze it

**What it analyzes:**
- Directory structure
- File types and distribution
- Executables and libraries
- Scripts and environment setup files
- Symbolic links
- Hardcoded paths that may need adjustment

**Usage:**
```bash
./analyze_existing_install.sh /opt/myapp
./analyze_existing_install.sh /usr/local/customapp
```

**Output:**
Creates `analysis_YYYYMMDD_HHMMSS/` with:
- `installbuilder_template.xml` - **Pre-built XML for InstallBuilder**
- `all_files.txt` - Complete file inventory
- `executables.txt` - All executable files
- `libraries.txt` - All shared libraries
- `env_scripts.txt` - Environment setup scripts found
- `SUMMARY.txt` - Quick overview

## Workflow

### For New Installation (Recommended)

1. **Monitor the installation:**
   ```bash
   ./monitor_install.sh myapp-1.0.tar.gz
   ```

2. **Review the generated recipe:**
   ```bash
   cat install_logs_*/installbuilder_recipe.txt
   ```

3. **Check for environment changes:**
   ```bash
   cat install_logs_*/environment_changes.log
   cat install_logs_*/profile_modifications.log
   ```

4. **Copy files to InstallBuilder project:**
   ```bash
   # Copy the extracted files
   cp -r install_logs_*/extracted/* /path/to/installbuilder/project/files/
   ```

5. **Update installer-template.xml:**
   - Use the XML snippets from `installbuilder_recipe.txt`
   - Add file components
   - Add environment variables
   - Add post-installation actions

### For Existing Installation

1. **Analyze the installation:**
   ```bash
   ./analyze_existing_install.sh /opt/myapp
   ```

2. **Review the analysis:**
   ```bash
   cat analysis_*/SUMMARY.txt
   ```

3. **Use the generated template:**
   ```bash
   cat analysis_*/installbuilder_template.xml
   # Copy relevant parts to your installer-template.xml
   ```

## What to Look For

### Files to Include in InstallBuilder

Check these logs:
- `files_installed.log` or `all_files.txt` - Complete file list
- `directories_created.log` - Directory structure to recreate

### Environment Setup

Check these logs:
- `environment_changes.log` - New/modified variables
- `profile_modifications.log` - Changes to .bashrc, .profile, etc.
- `env_scripts.txt` - Setup scripts that set environment

Common environment variables to add:
- **PATH** - For executable binaries
- **LD_LIBRARY_PATH** - For shared libraries
- **MANPATH** - For man pages
- **PKG_CONFIG_PATH** - For pkg-config files
- Application-specific variables

### Aliases and Shell Functions

Check `environment_changes.log` for:
- Aliases added to .bashrc
- Shell functions defined
- Custom completions

These should be added as post-installation scripts in InstallBuilder.

### Hardcoded Paths

Check `hardcoded_paths.txt` for:
- Absolute paths in binaries
- Paths in configuration files
- Scripts with hardcoded locations

These may need to be:
- Replaced with `${installdir}` variable
- Made configurable
- Fixed with post-installation scripts

## InstallBuilder Integration

### 1. File Components

From the monitoring logs, create `<folder>` entries:

```xml
<fileList>
    <folder>
        <description>Program Executables</description>
        <destination>${installdir}/bin</destination>
        <name>binfiles</name>
        <platforms>all</platforms>
    </folder>
    <folder>
        <description>Shared Libraries</description>
        <destination>${installdir}/lib</destination>
        <name>libfiles</name>
        <platforms>all</platforms>
    </folder>
</fileList>
```

### 2. Environment Variables

Add detected environment changes:

```xml
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
```

### 3. Post-Installation Scripts

If the original installer runs scripts, add them:

```xml
<postInstallationActionList>
    <runProgram>
        <program>${installdir}/bin/post-install.sh</program>
        <programArguments>--configure</programArguments>
    </runProgram>
</postInstallationActionList>
```

### 4. Symbolic Links

If `symlinks.txt` shows important links, create them:

```xml
<postInstallationActionList>
    <createSymLink>
        <destination>${installdir}/lib/libfoo.so</destination>
        <linkName>${installdir}/lib/libfoo.so.1</linkName>
    </createSymLink>
</postInstallationActionList>
```

## Tips and Best Practices

1. **Run as regular user when possible**
   - Monitors user-space changes more accurately
   - Safer than running as root

2. **Run as root only if needed**
   - Required for system-wide installations
   - Monitors /usr, /etc, /var changes

3. **Clean environment before monitoring**
   - Run on a clean VM or container
   - Minimizes false positives in change detection

4. **Test the InstallBuilder package**
   - Install on a clean system
   - Verify all files are present
   - Test environment variables work
   - Check that the app runs correctly

5. **Compare original vs InstallBuilder**
   ```bash
   # After creating InstallBuilder package
   ./analyze_existing_install.sh /path/to/original
   ./analyze_existing_install.sh /path/to/installbuilder/installed
   diff -r analysis_*/all_files.txt
   ```

## Common Issues and Solutions

### Issue: Too many files detected
**Solution:** The filesystem snapshot may include unrelated changes. Review `files_installed.log` and filter out system files.

### Issue: Environment changes not detected
**Solution:** The installer may modify files in /etc/profile.d/ - check `profile_modifications.log`.

### Issue: Hardcoded paths in binaries
**Solution:** Use InstallBuilder's `<substitute>` action or patchelf to fix RPATHs.

### Issue: Missing dependencies
**Solution:** Use `ldd` on executables to find required libraries:
```bash
ldd /path/to/executable
```

## Examples

### Example 1: Simple Application
```bash
# Monitor installation
./monitor_install.sh simple-app-1.0.tar.gz

# Review results
cat install_logs_*/installbuilder_recipe.txt

# Files went to: /opt/simple-app/
# PATH modified: yes
# No libraries: no
```

### Example 2: Complex Application
```bash
# Application with custom install path
./monitor_install.sh complex-app.tar.gz './installer.sh --prefix=$HOME/apps'

# Check what changed
cat install_logs_*/environment_changes.log
cat install_logs_*/files_installed.log
```

### Example 3: Analyze System Installation
```bash
# Already installed in /usr/local
./analyze_existing_install.sh /usr/local/myapp

# Review the structure
cat analysis_*/directory_structure.txt
cat analysis_*/installbuilder_template.xml
```

## Support

For issues or questions:
1. Check the log files in the output directory
2. Review the SUMMARY.txt or installation_summary.log
3. Verify file permissions on the scripts (should be executable)

## Files Generated

Both tools create timestamped directories to avoid overwriting previous runs:
- `monitor_install.sh` → `install_logs_YYYYMMDD_HHMMSS/`
- `analyze_existing_install.sh` → `analysis_YYYYMMDD_HHMMSS/`

All outputs are plain text files that can be:
- Viewed with any text editor
- Searched with grep
- Processed with scripts
- Archived for later reference
