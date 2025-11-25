#!/bin/bash
#
# Installation Monitor Script
# Monitors and logs all activities from a tar.gz installation
# Useful for recreating installations with InstallBuilder
#
# Usage: ./monitor_install.sh <tarball.tar.gz> [install_command]
#

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${SCRIPT_DIR}/install_logs_${TIMESTAMP}"
TARBALL="$1"
INSTALL_CMD="${2:-}"

# Log files
MAIN_LOG="${LOG_DIR}/installation_summary.log"
FILES_LOG="${LOG_DIR}/files_installed.log"
DIRS_LOG="${LOG_DIR}/directories_created.log"
ENV_BEFORE="${LOG_DIR}/environment_before.log"
ENV_AFTER="${LOG_DIR}/environment_after.log"
ENV_DIFF="${LOG_DIR}/environment_changes.log"
FS_SNAPSHOT_BEFORE="${LOG_DIR}/filesystem_before.txt"
FS_SNAPSHOT_AFTER="${LOG_DIR}/filesystem_after.txt"
PROCESSES_LOG="${LOG_DIR}/processes_spawned.log"
INSTALLBUILDER_RECIPE="${LOG_DIR}/installbuilder_recipe.txt"

# Print colored message
print_msg() {
    local color=$1
    shift
    echo -e "${color}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "${MAIN_LOG}"
}

# Print section header
print_section() {
    echo "" | tee -a "${MAIN_LOG}"
    echo "========================================" | tee -a "${MAIN_LOG}"
    echo "$1" | tee -a "${MAIN_LOG}"
    echo "========================================" | tee -a "${MAIN_LOG}"
}

# Check if running as root
check_root() {
    if [ "$EUID" -eq 0 ]; then
        print_msg "${YELLOW}" "WARNING: Running as root. Will monitor system-wide changes."
        return 0
    else
        print_msg "${BLUE}" "Running as regular user. Will monitor user-space changes."
        return 1
    fi
}

# Capture current environment
capture_environment() {
    local output_file=$1
    print_msg "${BLUE}" "Capturing environment to: ${output_file}"

    {
        echo "# Environment Variables"
        env | sort
        echo ""
        echo "# PATH"
        echo "${PATH}" | tr ':' '\n'
        echo ""
        echo "# LD_LIBRARY_PATH"
        echo "${LD_LIBRARY_PATH:-<not set>}" | tr ':' '\n'
        echo ""
        echo "# Shell Aliases"
        alias 2>/dev/null || echo "No aliases"
        echo ""
        echo "# Shell Functions"
        declare -F 2>/dev/null || echo "No functions"
        echo ""
        echo "# Bash Profile Files"
        ls -la ~/.bashrc ~/.bash_profile ~/.profile ~/.bash_aliases 2>/dev/null || echo "No profile files"
        echo ""
        echo "# System Profile Files"
        ls -la /etc/profile /etc/profile.d/* /etc/bash.bashrc /etc/environment 2>/dev/null || echo "No system profile files"
    } > "${output_file}"
}

# Capture filesystem snapshot
capture_filesystem() {
    local output_file=$1
    local search_paths=("$HOME" "/usr/local" "/opt")

    # If root, add more paths
    if [ "$EUID" -eq 0 ]; then
        search_paths+=("/usr" "/etc" "/var")
    fi

    print_msg "${BLUE}" "Capturing filesystem snapshot (this may take a while)..."

    {
        for path in "${search_paths[@]}"; do
            if [ -d "$path" ]; then
                echo "# Files in ${path}"
                find "$path" -type f -o -type l 2>/dev/null | sort
            fi
        done
    } > "${output_file}"
}

# Monitor running processes
monitor_processes() {
    print_msg "${BLUE}" "Monitoring process creation..."

    # Start process monitoring in background
    (
        while true; do
            ps aux | grep -v grep | grep -v "monitor_install"
            sleep 2
        done
    ) > "${PROCESSES_LOG}" 2>&1 &

    echo $! > "${LOG_DIR}/monitor_pid.tmp"
}

# Stop process monitoring
stop_monitoring() {
    if [ -f "${LOG_DIR}/monitor_pid.tmp" ]; then
        local pid=$(cat "${LOG_DIR}/monitor_pid.tmp")
        kill "$pid" 2>/dev/null || true
        rm -f "${LOG_DIR}/monitor_pid.tmp"
    fi
}

# Extract tarball and inspect contents
inspect_tarball() {
    local tarball=$1

    print_section "TARBALL INSPECTION"

    if [ ! -f "$tarball" ]; then
        print_msg "${RED}" "ERROR: Tarball not found: ${tarball}"
        exit 1
    fi

    print_msg "${GREEN}" "Tarball: ${tarball}"
    print_msg "${BLUE}" "Size: $(du -h "${tarball}" | cut -f1)"

    # List contents
    print_msg "${BLUE}" "Listing tarball contents..."
    {
        echo "# Tarball Contents"
        tar -tzf "$tarball" 2>/dev/null || tar -tjf "$tarball" 2>/dev/null
    } > "${LOG_DIR}/tarball_contents.log"

    local file_count=$(wc -l < "${LOG_DIR}/tarball_contents.log")
    print_msg "${GREEN}" "Total files in tarball: ${file_count}"

    # Check for install scripts
    print_msg "${BLUE}" "Searching for installation scripts..."
    {
        echo "# Installation Scripts Found"
        tar -tzf "$tarball" 2>/dev/null | grep -E "(install|setup|configure|\.sh$)" || echo "No obvious install scripts"
    } > "${LOG_DIR}/install_scripts.log"

    cat "${LOG_DIR}/install_scripts.log" | tee -a "${MAIN_LOG}"
}

# Extract tarball to temporary location
extract_tarball() {
    local tarball=$1
    local extract_dir="${LOG_DIR}/extracted"

    print_section "EXTRACTING TARBALL"

    mkdir -p "$extract_dir"
    print_msg "${BLUE}" "Extracting to: ${extract_dir}"

    tar -xzf "$tarball" -C "$extract_dir" 2>/dev/null || tar -xjf "$tarball" -C "$extract_dir"

    print_msg "${GREEN}" "Extraction complete"

    # Find potential install scripts
    print_msg "${BLUE}" "Looking for executable scripts..."
    find "$extract_dir" -type f -executable > "${LOG_DIR}/executable_files.log"

    if [ -s "${LOG_DIR}/executable_files.log" ]; then
        print_msg "${GREEN}" "Found executable files:"
        cat "${LOG_DIR}/executable_files.log" | tee -a "${MAIN_LOG}"
    fi

    echo "$extract_dir"
}

# Run installation with monitoring
run_installation() {
    local extract_dir=$1
    local install_cmd=$2

    print_section "RUNNING INSTALLATION"

    if [ -z "$install_cmd" ]; then
        print_msg "${YELLOW}" "No install command provided. Looking for common install scripts..."

        # Search for common installation scripts
        for script in "install.sh" "setup.sh" "configure" "install" "setup"; do
            if [ -x "${extract_dir}/${script}" ]; then
                install_cmd="./${script}"
                print_msg "${GREEN}" "Found: ${install_cmd}"
                break
            fi
        done

        if [ -z "$install_cmd" ]; then
            print_msg "${YELLOW}" "No automatic install script found."
            print_msg "${BLUE}" "Available executable files:"
            cat "${LOG_DIR}/executable_files.log"

            echo ""
            print_msg "${YELLOW}" "Please specify the installation command as second argument:"
            print_msg "${YELLOW}" "  $0 <tarball> '<install_command>'"
            return 1
        fi
    fi

    print_msg "${GREEN}" "Executing: ${install_cmd}"
    print_msg "${BLUE}" "Working directory: ${extract_dir}"

    # Capture before state
    print_msg "${BLUE}" "Capturing pre-installation state..."
    capture_environment "${ENV_BEFORE}"
    capture_filesystem "${FS_SNAPSHOT_BEFORE}"

    # Monitor processes
    monitor_processes

    # Run installation
    cd "$extract_dir"
    print_msg "${GREEN}" "Starting installation..."
    echo "===== Installation Output =====" | tee -a "${MAIN_LOG}"

    # Run with script to capture all output
    script -q -c "${install_cmd}" "${LOG_DIR}/install_output.log" || {
        print_msg "${RED}" "Installation command exited with error code: $?"
        print_msg "${YELLOW}" "Continuing with post-installation analysis..."
    }

    cd "$SCRIPT_DIR"

    # Stop monitoring
    stop_monitoring

    print_msg "${GREEN}" "Installation complete"
}

# Analyze changes
analyze_changes() {
    print_section "ANALYZING CHANGES"

    # Capture after state
    print_msg "${BLUE}" "Capturing post-installation state..."
    capture_environment "${ENV_AFTER}"
    capture_filesystem "${FS_SNAPSHOT_AFTER}"

    # Compare environments
    print_msg "${BLUE}" "Comparing environment changes..."
    {
        echo "# Environment Changes"
        echo ""
        echo "## New/Modified Environment Variables"
        diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep "^>" | sed 's/^> //' || echo "No changes"
    } > "${ENV_DIFF}"

    # Compare filesystems
    print_msg "${BLUE}" "Comparing filesystem changes..."
    {
        echo "# New Files Installed"
        comm -13 "${FS_SNAPSHOT_BEFORE}" "${FS_SNAPSHOT_AFTER}"
    } > "${FILES_LOG}"

    local new_files=$(wc -l < "${FILES_LOG}")
    print_msg "${GREEN}" "New files detected: ${new_files}"

    # Detect new directories
    {
        grep "^/" "${FILES_LOG}" | xargs -I {} dirname {} | sort -u
    } > "${DIRS_LOG}" 2>/dev/null || true

    # Scan for profile modifications
    print_msg "${BLUE}" "Checking for profile file modifications..."
    {
        echo "# Profile File Modifications"
        for file in ~/.bashrc ~/.bash_profile ~/.profile ~/.bash_aliases /etc/profile; do
            if [ -f "$file" ]; then
                echo "## ${file}"
                if grep -q "$(basename "$TARBALL" .tar.gz)" "$file" 2>/dev/null; then
                    echo "MODIFIED - Contains references to installation"
                    grep -n "$(basename "$TARBALL" .tar.gz)" "$file" || true
                else
                    echo "No obvious modifications"
                fi
                echo ""
            fi
        done
    } > "${LOG_DIR}/profile_modifications.log"

    cat "${LOG_DIR}/profile_modifications.log" | tee -a "${MAIN_LOG}"
}

# Generate InstallBuilder recipe
generate_installbuilder_recipe() {
    print_section "GENERATING INSTALLBUILDER RECIPE"

    print_msg "${BLUE}" "Creating InstallBuilder recipe..."

    {
        echo "# InstallBuilder Recreation Recipe"
        echo "# Generated: $(date)"
        echo "# Source: ${TARBALL}"
        echo ""
        echo "========================================="
        echo "FILES TO INCLUDE IN INSTALLBUILDER"
        echo "========================================="
        echo ""

        # Group files by directory
        echo "## Installation Directories:"
        cat "${DIRS_LOG}" | head -20
        echo ""
        if [ $(wc -l < "${DIRS_LOG}") -gt 20 ]; then
            echo "... and $(($(wc -l < "${DIRS_LOG}") - 20)) more directories"
            echo "See ${DIRS_LOG} for complete list"
        fi
        echo ""

        echo "## Sample Files (first 50):"
        head -50 "${FILES_LOG}"
        echo ""
        if [ $(wc -l < "${FILES_LOG}") -gt 50 ]; then
            echo "... and $(($(wc -l < "${FILES_LOG}") - 50)) more files"
            echo "See ${FILES_LOG} for complete list"
        fi
        echo ""

        echo "========================================="
        echo "ENVIRONMENT MODIFICATIONS"
        echo "========================================="
        echo ""

        # Extract PATH additions
        echo "## PATH Additions:"
        diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep "^> .*PATH=" | sed 's/^> //' || echo "None detected"
        echo ""

        echo "## LD_LIBRARY_PATH Additions:"
        diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep "^> .*LD_LIBRARY_PATH=" | sed 's/^> //' || echo "None detected"
        echo ""

        echo "## New Environment Variables:"
        diff <(grep "^[A-Z_]*=" "${ENV_BEFORE}" | cut -d= -f1 | sort) \
             <(grep "^[A-Z_]*=" "${ENV_AFTER}" | cut -d= -f1 | sort) | \
             grep "^>" | sed 's/^> //' || echo "None detected"
        echo ""

        echo "========================================="
        echo "INSTALLBUILDER XML SNIPPETS"
        echo "========================================="
        echo ""

        echo "<!-- Add these to your installer-template.xml -->"
        echo ""
        echo "<!-- 1. File Components -->"
        echo "<fileList>"

        # Generate folder entries for top-level directories
        local top_dirs=$(cat "${DIRS_LOG}" | cut -d/ -f1-3 | sort -u | head -10)
        for dir in $top_dirs; do
            if [ -n "$dir" ]; then
                echo "    <folder>"
                echo "        <destination>${dir}</destination>"
                echo "        <name>files_$(basename "$dir")</name>"
                echo "        <platforms>all</platforms>"
                echo "    </folder>"
            fi
        done

        echo "</fileList>"
        echo ""

        echo "<!-- 2. Environment Variables -->"
        echo "<postInstallationActionList>"

        # Add PATH modification if detected
        if diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep -q "PATH="; then
            echo "    <addEnvironmentVariable>"
            echo "        <name>PATH</name>"
            echo "        <value>\${installdir}/bin:\${env(PATH)}</value>"
            echo "    </addEnvironmentVariable>"
        fi

        # Add LD_LIBRARY_PATH if detected
        if diff "${ENV_BEFORE}" "${ENV_AFTER}" | grep -q "LD_LIBRARY_PATH="; then
            echo "    <addEnvironmentVariable>"
            echo "        <name>LD_LIBRARY_PATH</name>"
            echo "        <value>\${installdir}/lib:\${env(LD_LIBRARY_PATH)}</value>"
            echo "    </addEnvironmentVariable>"
        fi

        echo "</postInstallationActionList>"
        echo ""

        echo "========================================="
        echo "MANUAL STEPS REQUIRED"
        echo "========================================="
        echo ""
        echo "1. Review ${FILES_LOG} for complete file list"
        echo "2. Copy files to InstallBuilder project structure"
        echo "3. Update installer-template.xml with file locations"
        echo "4. Test the installer in a clean environment"
        echo "5. Review ${LOG_DIR}/profile_modifications.log for any shell customizations"
        echo ""

    } > "${INSTALLBUILDER_RECIPE}"

    print_msg "${GREEN}" "InstallBuilder recipe created: ${INSTALLBUILDER_RECIPE}"
}

# Print summary
print_summary() {
    print_section "INSTALLATION MONITORING SUMMARY"

    echo "" | tee -a "${MAIN_LOG}"
    print_msg "${GREEN}" "All logs saved to: ${LOG_DIR}"
    echo "" | tee -a "${MAIN_LOG}"

    echo "Log Files:" | tee -a "${MAIN_LOG}"
    echo "  - Main log:              ${MAIN_LOG}" | tee -a "${MAIN_LOG}"
    echo "  - Files installed:       ${FILES_LOG}" | tee -a "${MAIN_LOG}"
    echo "  - Directories created:   ${DIRS_LOG}" | tee -a "${MAIN_LOG}"
    echo "  - Environment changes:   ${ENV_DIFF}" | tee -a "${MAIN_LOG}"
    echo "  - InstallBuilder recipe: ${INSTALLBUILDER_RECIPE}" | tee -a "${MAIN_LOG}"
    echo "" | tee -a "${MAIN_LOG}"

    print_msg "${BLUE}" "Quick Stats:"
    echo "  - New files:       $(wc -l < "${FILES_LOG}")" | tee -a "${MAIN_LOG}"
    echo "  - New directories: $(wc -l < "${DIRS_LOG}")" | tee -a "${MAIN_LOG}"
    echo "" | tee -a "${MAIN_LOG}"

    print_msg "${GREEN}" "Next Steps:"
    echo "  1. Review ${INSTALLBUILDER_RECIPE}"
    echo "  2. Check ${LOG_DIR}/profile_modifications.log for aliases/functions"
    echo "  3. Examine ${FILES_LOG} for all installed files"
    echo "  4. Update your InstallBuilder project with the findings"
    echo ""
}

# Main execution
main() {
    # Print banner
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║     Installation Monitor for InstallBuilder            ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""

    # Validate arguments
    if [ $# -lt 1 ]; then
        echo "Usage: $0 <tarball.tar.gz> [install_command]"
        echo ""
        echo "Examples:"
        echo "  $0 myapp.tar.gz"
        echo "  $0 myapp.tar.gz './install.sh'"
        echo "  $0 myapp.tar.gz 'bash setup.sh --prefix=/opt/myapp'"
        echo ""
        exit 1
    fi

    # Create log directory
    mkdir -p "${LOG_DIR}"

    # Start logging
    print_msg "${GREEN}" "Starting installation monitoring..."
    print_msg "${BLUE}" "Log directory: ${LOG_DIR}"

    # Check privileges
    check_root

    # Inspect tarball
    inspect_tarball "$TARBALL"

    # Extract tarball
    EXTRACT_DIR=$(extract_tarball "$TARBALL")

    # Run installation
    if run_installation "$EXTRACT_DIR" "$INSTALL_CMD"; then
        # Analyze changes
        sleep 2  # Give system time to settle
        analyze_changes

        # Generate recipe
        generate_installbuilder_recipe
    fi

    # Print summary
    print_summary

    print_msg "${GREEN}" "Monitoring complete!"
}

# Run main function
main "$@"
