#!/bin/bash
#
# Monitor .run Installer Script
# Specifically designed for .run files (like ADM-2024.0-installer.run)
# that are extracted from tar.gz archives
#
# Usage: ./monitor_run_installer.sh <tarball.tar.gz> [install_options]
#

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${SCRIPT_DIR}/run_install_logs_${TIMESTAMP}"
TARBALL="${1:-}"
INSTALL_OPTIONS="${2:-}"

# Log files
MAIN_LOG="${LOG_DIR}/installation_summary.log"
FILES_LOG="${LOG_DIR}/files_installed.log"
DIRS_LOG="${LOG_DIR}/directories_created.log"
ENV_BEFORE="${LOG_DIR}/environment_before.log"
ENV_AFTER="${LOG_DIR}/environment_after.log"
ENV_DIFF="${LOG_DIR}/environment_changes.log"
STRACE_LOG="${LOG_DIR}/strace_output.log"
FS_SNAPSHOT_BEFORE="${LOG_DIR}/filesystem_before.txt"
FS_SNAPSHOT_AFTER="${LOG_DIR}/filesystem_after.txt"
INSTALLER_OUTPUT="${LOG_DIR}/installer_output.log"
INSTALLBUILDER_RECIPE="${LOG_DIR}/installbuilder_recipe.txt"
RUN_FILE=""

print_msg() {
    local color=$1
    shift
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${MAIN_LOG}"
}

print_section() {
    echo "" | tee -a "${MAIN_LOG}"
    echo "========================================" | tee -a "${MAIN_LOG}"
    echo "$1" | tee -a "${MAIN_LOG}"
    echo "========================================" | tee -a "${MAIN_LOG}"
}

print_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     .RUN Installer Monitor for InstallBuilder          ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
}

# Check for required tools
check_tools() {
    local missing_tools=()

    for tool in tar strace file; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        print_msg "${YELLOW}" "WARNING: Missing tools: ${missing_tools[*]}"
        print_msg "${BLUE}" "Installing strace is recommended for detailed monitoring"
        if [ "${missing_tools[*]}" == *"strace"* ]; then
            print_msg "${BLUE}" "Install with: sudo apt-get install strace (Debian/Ubuntu)"
            print_msg "${BLUE}" "           or: sudo yum install strace (RHEL/CentOS)"
        fi
    fi
}

# Capture environment
capture_environment() {
    local output_file=$1
    {
        echo "# Environment Variables"
        env | sort
        echo ""
        echo "# PATH"
        echo "${PATH}" | tr ':' '\n'
        echo ""
        echo "# LD_LIBRARY_PATH"
        echo "${LD_LIBRARY_PATH:-<not set>}"
        echo ""
        echo "# Shell Aliases"
        alias 2>/dev/null || echo "No aliases"
        echo ""
        echo "# Profile Files"
        for f in ~/.bashrc ~/.bash_profile ~/.profile ~/.bash_aliases /etc/profile; do
            if [ -f "$f" ]; then
                echo "## $f"
                ls -la "$f"
            fi
        done
    } > "${output_file}"
}

# Capture filesystem snapshot
capture_filesystem() {
    local output_file=$1
    local search_paths=("$HOME" "/usr/local" "/opt")

    if [ "$EUID" -eq 0 ]; then
        search_paths+=("/usr" "/etc")
    fi

    print_msg "${BLUE}" "Capturing filesystem snapshot..."
    {
        for path in "${search_paths[@]}"; do
            if [ -d "$path" ]; then
                find "$path" -type f -o -type l 2>/dev/null | sort
            fi
        done
    } > "${output_file}"
}

# Extract and find .run file
extract_and_find_run() {
    local tarball=$1

    print_section "EXTRACTING TARBALL"

    if [ ! -f "$tarball" ]; then
        print_msg "${RED}" "ERROR: File not found: ${tarball}"
        exit 1
    fi

    print_msg "${GREEN}" "Tarball: ${tarball}"
    print_msg "${BLUE}" "Size: $(du -h "${tarball}" | cut -f1)"

    # Create extraction directory
    local extract_dir="${LOG_DIR}/extracted"
    mkdir -p "$extract_dir"

    # Extract
    print_msg "${BLUE}" "Extracting tarball..."
    tar -xzf "$tarball" -C "$extract_dir" 2>/dev/null || tar -xjf "$tarball" -C "$extract_dir" 2>/dev/null

    print_msg "${GREEN}" "Extraction complete"

    # List contents
    {
        echo "# Extracted Contents"
        find "$extract_dir" -type f
    } > "${LOG_DIR}/extracted_contents.log"

    # Find .run file
    print_msg "${BLUE}" "Searching for .run installer..."
    local run_files=($(find "$extract_dir" -type f -name "*.run"))

    if [ ${#run_files[@]} -eq 0 ]; then
        print_msg "${RED}" "ERROR: No .run file found in tarball"
        print_msg "${BLUE}" "Contents:"
        cat "${LOG_DIR}/extracted_contents.log"
        exit 1
    fi

    if [ ${#run_files[@]} -gt 1 ]; then
        print_msg "${YELLOW}" "Multiple .run files found:"
        printf '%s\n' "${run_files[@]}"
        RUN_FILE="${run_files[0]}"
        print_msg "${YELLOW}" "Using: ${RUN_FILE}"
    else
        RUN_FILE="${run_files[0]}"
        print_msg "${GREEN}" "Found: ${RUN_FILE}"
    fi

    # Analyze the .run file
    print_msg "${BLUE}" "Analyzing .run file..."
    {
        echo "# .run File Analysis"
        echo "File: ${RUN_FILE}"
        echo "Size: $(du -h "${RUN_FILE}" | cut -f1)"
        echo "Type: $(file "${RUN_FILE}")"
        echo "Permissions: $(ls -la "${RUN_FILE}")"
        echo ""
        echo "# First 100 lines (checking for install options)"
        head -100 "${RUN_FILE}"
    } > "${LOG_DIR}/run_file_analysis.log"

    # Make executable if needed
    if [ ! -x "$RUN_FILE" ]; then
        print_msg "${YELLOW}" "Making .run file executable..."
        chmod +x "$RUN_FILE"
    fi

    echo "$RUN_FILE"
}

# Check .run file for options
check_installer_options() {
    local run_file=$1

    print_section "INSTALLER OPTIONS"

    print_msg "${BLUE}" "Checking for help/usage information..."

    {
        echo "# Trying --help"
        "$run_file" --help 2>&1 || true
        echo ""
        echo "# Trying -h"
        "$run_file" -h 2>&1 || true
        echo ""
        echo "# Trying --usage"
        "$run_file" --usage 2>&1 || true
        echo ""
        echo "# Searching for common options in file"
        strings "$run_file" | grep -E "^\-\-" | head -20 || true
    } > "${LOG_DIR}/installer_options.log"

    if grep -q "help\|usage\|prefix\|silent" "${LOG_DIR}/installer_options.log" 2>/dev/null; then
        print_msg "${GREEN}" "Found installer options:"
        grep -E "help|usage|prefix|silent|unattended|accept|license" "${LOG_DIR}/installer_options.log" | head -20 || true
    else
        print_msg "${YELLOW}" "No standard help output found"
        print_msg "${BLUE}" "Common options to try: --help, --prefix, --mode unattended, --accept-license"
    fi
}

# Run installer with monitoring
run_installer() {
    local run_file=$1
    local install_opts=$2

    print_section "RUNNING INSTALLER WITH MONITORING"

    # Capture before state
    print_msg "${BLUE}" "Capturing pre-installation state..."
    capture_environment "${ENV_BEFORE}"
    capture_filesystem "${FS_SNAPSHOT_BEFORE}"

    # Determine if strace is available
    local use_strace=false
    if command -v strace &> /dev/null; then
        use_strace=true
        print_msg "${GREEN}" "Using strace for detailed system call monitoring"
    else
        print_msg "${YELLOW}" "strace not available - limited monitoring"
    fi

    # Build install command
    local install_cmd="$run_file"
    if [ -n "$install_opts" ]; then
        install_cmd="$install_cmd $install_opts"
    fi

    print_msg "${GREEN}" "Install command: ${install_cmd}"
    print_msg "${CYAN}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Run installer
    if [ "$use_strace" = true ]; then
        # With strace
        print_msg "${BLUE}" "Running with strace (this will be slower but more detailed)..."
        strace -f -e trace=open,openat,creat,unlink,mkdir,chmod,chown,execve,clone \
               -o "$STRACE_LOG" \
               $install_cmd 2>&1 | tee "$INSTALLER_OUTPUT"
    else
        # Without strace
        $install_cmd 2>&1 | tee "$INSTALLER_OUTPUT"
    fi

    local exit_code=${PIPESTATUS[0]}

    print_msg "${CYAN}" "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ $exit_code -eq 0 ]; then
        print_msg "${GREEN}" "Installer completed successfully"
    else
        print_msg "${YELLOW}" "Installer exited with code: ${exit_code}"
        print_msg "${BLUE}" "Check ${INSTALLER_OUTPUT} for details"
    fi

    # Give system time to settle
    sleep 2

    # Capture after state
    print_msg "${BLUE}" "Capturing post-installation state..."
    capture_environment "${ENV_AFTER}"
    capture_filesystem "${FS_SNAPSHOT_AFTER}"
}

# Analyze installation from strace
analyze_strace() {
    if [ ! -f "$STRACE_LOG" ]; then
        return
    fi

    print_section "ANALYZING SYSTEM CALLS"

    print_msg "${BLUE}" "Extracting installation details from strace..."

    # Extract files created/opened for writing
    {
        echo "# Files Created or Modified"
        grep -E "openat|creat" "$STRACE_LOG" | \
            grep -E "O_WRONLY|O_RDWR|O_CREAT" | \
            grep -oP '"\K[^"]+' | \
            grep -v "^/tmp\|^/proc\|^/dev\|^/sys" | \
            sort -u
    } > "${LOG_DIR}/strace_files_created.log"

    # Extract directories created
    {
        echo "# Directories Created"
        grep "mkdir" "$STRACE_LOG" | \
            grep -oP '"\K[^"]+' | \
            sort -u
    } > "${LOG_DIR}/strace_dirs_created.log"

    # Extract executed commands
    {
        echo "# Commands Executed During Installation"
        grep "execve" "$STRACE_LOG" | \
            grep -oP '"\K[^"]+' | \
            sort -u
    } > "${LOG_DIR}/strace_commands.log"

    print_msg "${GREEN}" "Strace analysis complete"

    if [ -s "${LOG_DIR}/strace_files_created.log" ]; then
        local file_count=$(wc -l < "${LOG_DIR}/strace_files_created.log")
        print_msg "${BLUE}" "Files created/modified: ${file_count}"
    fi
}

# Analyze changes
analyze_changes() {
    print_section "ANALYZING INSTALLATION CHANGES"

    # Compare environments
    print_msg "${BLUE}" "Comparing environments..."
    {
        echo "# Environment Variable Changes"
        diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep "^>" | sed 's/^> //' || echo "No changes detected"
    } > "${ENV_DIFF}"

    # Compare filesystems
    print_msg "${BLUE}" "Comparing filesystems..."
    {
        echo "# New Files Installed"
        comm -13 "${FS_SNAPSHOT_BEFORE}" "${FS_SNAPSHOT_AFTER}"
    } > "${FILES_LOG}"

    local new_files=$(wc -l < "${FILES_LOG}")
    print_msg "${GREEN}" "New files detected: ${new_files}"

    # Extract unique directories
    {
        grep "^/" "${FILES_LOG}" | xargs -I {} dirname {} | sort -u
    } > "${DIRS_LOG}" 2>/dev/null || true

    # Try to detect installation directory
    print_msg "${BLUE}" "Detecting installation directory..."
    local install_dir=$(grep -E "^/(opt|usr/local|home)" "${DIRS_LOG}" | head -1)

    if [ -n "$install_dir" ]; then
        print_msg "${GREEN}" "Primary installation directory: ${install_dir}"
        echo "$install_dir" > "${LOG_DIR}/install_directory.txt"
    else
        print_msg "${YELLOW}" "Could not auto-detect installation directory"
        print_msg "${BLUE}" "Check ${DIRS_LOG} for directory list"
    fi

    # Combine strace results if available
    if [ -f "${LOG_DIR}/strace_files_created.log" ]; then
        analyze_strace
    fi
}

# Scan for profile changes
scan_profile_changes() {
    print_msg "${BLUE}" "Scanning for shell profile modifications..."

    {
        echo "# Shell Profile Modifications"
        for file in ~/.bashrc ~/.bash_profile ~/.profile ~/.bash_aliases /etc/profile /etc/bash.bashrc; do
            if [ -f "$file" ]; then
                echo ""
                echo "## ${file}"
                # Check modification time
                local mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
                local install_time=$(stat -c %Y "$RUN_FILE" 2>/dev/null || echo 0)

                if [ $mtime -gt $install_time ]; then
                    echo "MODIFIED (changed after installer ran)"
                    echo "Last 20 lines:"
                    tail -20 "$file"
                else
                    echo "Not modified by installer"
                fi
            fi
        done

        # Check for new files in profile.d
        if [ -d /etc/profile.d ]; then
            echo ""
            echo "## /etc/profile.d/"
            find /etc/profile.d/ -type f -newer "$RUN_FILE" 2>/dev/null || echo "No new files"
        fi
    } > "${LOG_DIR}/profile_changes.log"
}

# Generate InstallBuilder recipe
generate_recipe() {
    print_section "GENERATING INSTALLBUILDER RECIPE"

    local install_dir=""
    if [ -f "${LOG_DIR}/install_directory.txt" ]; then
        install_dir=$(cat "${LOG_DIR}/install_directory.txt")
    fi

    {
        echo "╔════════════════════════════════════════════════════════╗"
        echo "║          InstallBuilder Recreation Recipe             ║"
        echo "╚════════════════════════════════════════════════════════╝"
        echo ""
        echo "Generated: $(date)"
        echo "Source: ${TARBALL}"
        echo "Installer: $(basename "$RUN_FILE")"
        if [ -n "$install_dir" ]; then
            echo "Install Directory: ${install_dir}"
        fi
        echo ""

        echo "========================================="
        echo "STEP 1: EXTRACT REAL FILES"
        echo "========================================="
        echo ""
        echo "The .run file is a self-extracting installer."
        echo "You need to extract its contents first."
        echo ""
        echo "Try one of these methods:"
        echo ""
        echo "Method 1: Use the --noexec option (if supported)"
        echo "  $ $(basename "$RUN_FILE") --noexec --target=extracted/"
        echo ""
        echo "Method 2: Use shell scripting"
        echo "  $ SKIP=\$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' $(basename "$RUN_FILE"))"
        echo "  $ tail -n +\$SKIP $(basename "$RUN_FILE") | tar xz"
        echo ""
        echo "Method 3: Search for embedded archive"
        echo "  $ strings $(basename "$RUN_FILE") | grep -i \"archive\""
        echo "  $ dd if=$(basename "$RUN_FILE") bs=1 skip=OFFSET | tar xz"
        echo ""

        echo "========================================="
        echo "STEP 2: INSTALLATION DETECTED"
        echo "========================================="
        echo ""

        if [ -s "${FILES_LOG}" ]; then
            echo "Files Installed: $(wc -l < "${FILES_LOG}")"
            echo "Directories: $(wc -l < "${DIRS_LOG}")"
            echo ""
            echo "Top Installation Directories:"
            head -10 "${DIRS_LOG}"
            echo ""
        fi

        if [ -f "${LOG_DIR}/strace_files_created.log" ] && [ -s "${LOG_DIR}/strace_files_created.log" ]; then
            echo "Files from strace: $(wc -l < "${LOG_DIR}/strace_files_created.log")"
        fi
        echo ""

        echo "========================================="
        echo "STEP 3: INSTALLBUILDER XML STRUCTURE"
        echo "========================================="
        echo ""
        echo "<!-- Add to installer-template.xml -->"
        echo ""

        if [ -n "$install_dir" ]; then
            local base_name=$(basename "$install_dir")
            echo "<project>"
            echo "    <shortName>${base_name}</shortName>"
            echo "    <fullName>$(echo $base_name | tr '[:lower:]' '[:upper:]')</fullName>"
            echo "    <version>2024.0</version>"
            echo "    <installerFilename>\${product_shortname}-\${product_version}-installer.run</installerFilename>"
            echo ""
            echo "    <componentList>"
            echo "        <component>"
            echo "            <name>default</name>"
            echo "            <description>Main Application</description>"
            echo "            <canBeEdited>0</canBeEdited>"
            echo "            <selected>1</selected>"
            echo "            <show>1</show>"
            echo "            <folderList>"

            # Suggest folder structure based on detected directories
            if grep -q "/bin$" "${DIRS_LOG}" 2>/dev/null; then
                echo "                <folder>"
                echo "                    <description>Executables</description>"
                echo "                    <destination>\${installdir}/bin</destination>"
                echo "                    <name>binfiles</name>"
                echo "                </folder>"
            fi

            if grep -q "/lib" "${DIRS_LOG}" 2>/dev/null; then
                echo "                <folder>"
                echo "                    <description>Libraries</description>"
                echo "                    <destination>\${installdir}/lib</destination>"
                echo "                    <name>libfiles</name>"
                echo "                </folder>"
            fi

            echo "            </folderList>"
            echo "        </component>"
            echo "    </componentList>"
            echo "</project>"
        fi
        echo ""

        echo "========================================="
        echo "STEP 4: ENVIRONMENT SETUP"
        echo "========================================="
        echo ""

        if [ -s "${ENV_DIFF}" ] && grep -q "PATH=" "${ENV_DIFF}"; then
            echo "<!-- Environment Variables Detected -->"
            echo "<postInstallationActionList>"
            echo "    <addEnvironmentVariable>"
            echo "        <name>PATH</name>"
            echo "        <scope>system</scope>"
            echo "        <value>\${installdir}/bin:\${env(PATH)}</value>"
            echo "    </addEnvironmentVariable>"
            echo "</postInstallationActionList>"
        fi
        echo ""

        echo "========================================="
        echo "REFERENCE FILES"
        echo "========================================="
        echo ""
        echo "Review these files for complete details:"
        echo "  - ${INSTALLER_OUTPUT}"
        echo "  - ${FILES_LOG}"
        echo "  - ${DIRS_LOG}"
        echo "  - ${ENV_DIFF}"
        if [ -f "$STRACE_LOG" ]; then
            echo "  - ${STRACE_LOG}"
        fi
        echo ""

    } > "${INSTALLBUILDER_RECIPE}"

    print_msg "${GREEN}" "Recipe generated: ${INSTALLBUILDER_RECIPE}"
}

# Print summary
print_summary() {
    print_section "SUMMARY"

    {
        echo "Installation Monitoring Complete"
        echo ""
        echo "Tarball: ${TARBALL}"
        echo "Installer: $(basename "$RUN_FILE")"
        echo "Log Directory: ${LOG_DIR}"
        echo ""
        echo "Key Files:"
        echo "  - Installation summary: ${MAIN_LOG}"
        echo "  - Installer output:     ${INSTALLER_OUTPUT}"
        echo "  - Files installed:      ${FILES_LOG}"
        echo "  - Environment changes:  ${ENV_DIFF}"
        echo "  - InstallBuilder guide: ${INSTALLBUILDER_RECIPE}"
        echo ""
        if [ -f "$STRACE_LOG" ]; then
            echo "  - Detailed strace log:  ${STRACE_LOG}"
        fi
        echo ""
        echo "Next Steps:"
        echo "  1. Read: ${INSTALLBUILDER_RECIPE}"
        echo "  2. Extract contents from the .run file"
        echo "  3. Copy files to InstallBuilder project"
        echo "  4. Build and test your installer"
        echo ""
    } | tee -a "${MAIN_LOG}"
}

# Main function
main() {
    print_banner

    if [ -z "$TARBALL" ]; then
        echo "Usage: $0 <tarball.tar.gz> [installer_options]"
        echo ""
        echo "Examples:"
        echo "  $0 ADMORE2024r0_Linux.tar.gz"
        echo "  $0 ADMORE2024r0_Linux.tar.gz '--prefix=/opt/admore --mode unattended'"
        echo "  $0 ADMORE2024r0_Linux.tar.gz '--accept-license'"
        echo ""
        exit 1
    fi

    # Setup
    mkdir -p "$LOG_DIR"
    check_tools

    print_msg "${GREEN}" "Starting .run installer monitoring..."
    print_msg "${BLUE}" "Log directory: ${LOG_DIR}"

    # Extract and find .run file
    RUN_FILE=$(extract_and_find_run "$TARBALL")

    # Check for installer options
    check_installer_options "$RUN_FILE"

    # Ask user to confirm or provide options
    if [ -z "$INSTALL_OPTIONS" ]; then
        echo ""
        print_msg "${YELLOW}" "No installer options provided."
        print_msg "${BLUE}" "Press Enter to run installer interactively, or Ctrl+C to abort and rerun with options"
        read -p "Continue? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_msg "${BLUE}" "Aborted. Rerun with: $0 $TARBALL '<options>'"
            exit 0
        fi
    fi

    # Run installer with monitoring
    run_installer "$RUN_FILE" "$INSTALL_OPTIONS"

    # Analyze results
    analyze_changes
    scan_profile_changes

    # Generate recipe
    generate_recipe

    # Print summary
    print_summary

    print_msg "${GREEN}" "✓ Monitoring complete!"
}

main "$@"
