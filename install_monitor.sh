#!/bin/bash
#
# Universal Installation Monitor - Smart Launcher
# Automatically detects the type of installer and uses the right tool
#
# Usage: ./install_monitor.sh <file_or_directory> [options]
#

set -euo pipefail

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

INPUT="${1:-}"
OPTIONS="${2:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║       Universal Installation Monitor v1.0              ║"
    echo "║       Smart Launcher for InstallBuilder                ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
}

print_help() {
    cat << EOF
Universal Installation Monitor - Automatically detects and monitors installations

USAGE:
    ./install_monitor.sh <file_or_directory> [installer_options]

EXAMPLES:
    # Monitor .tar.gz with .run installer (like ADMORE)
    ./install_monitor.sh ADMORE2024r0_Linux.tar.gz

    # Monitor regular .tar.gz with install script
    ./install_monitor.sh myapp.tar.gz

    # Analyze existing installation
    ./install_monitor.sh /opt/installed-app

    # With installer options
    ./install_monitor.sh app.tar.gz '--mode unattended --prefix=/opt/app'

SUPPORTED FORMATS:
    - .tar.gz containing .run installer
    - .tar.gz containing install.sh or setup.sh
    - .tar.bz2 archives
    - Existing installation directories

OUTPUT:
    Creates timestamped log directory with:
    - Complete installation analysis
    - File and directory listings
    - Environment changes
    - InstallBuilder recipe (ready to use!)

For detailed help, see:
    - QUICK_START.md
    - ADMORE_EXAMPLE.md
    - README_INSTALL_MONITORING.md

EOF
}

detect_and_run() {
    local input=$1
    local opts=$2

    # Check if it's a directory
    if [ -d "$input" ]; then
        echo -e "${GREEN}→ Detected: Existing installation directory${NC}"
        echo -e "${BLUE}→ Using: analyze_existing_install.sh${NC}"
        echo ""
        exec "${SCRIPT_DIR}/scripts/analyze_existing_install.sh" "$input"
    fi

    # Check if it's a file
    if [ ! -f "$input" ]; then
        echo -e "${YELLOW}Error: File or directory not found: ${input}${NC}"
        exit 1
    fi

    # Detect file type
    local file_type=$(file "$input" | cut -d: -f2)

    case "$input" in
        *.tar.gz|*.tgz|*.tar.bz2|*.tbz)
            echo -e "${GREEN}→ Detected: Compressed archive${NC}"

            # Quick peek inside to see what type of installer it is
            echo -e "${BLUE}→ Inspecting archive contents...${NC}"

            local has_run=0
            local has_install_script=0

            if tar -tzf "$input" 2>/dev/null | grep -q "\.run$"; then
                has_run=1
            elif tar -tjf "$input" 2>/dev/null | grep -q "\.run$"; then
                has_run=1
            fi

            if tar -tzf "$input" 2>/dev/null | grep -qE "(install\.sh|setup\.sh|configure)"; then
                has_install_script=1
            elif tar -tjf "$input" 2>/dev/null | grep -qE "(install\.sh|setup\.sh|configure)"; then
                has_install_script=1
            fi

            if [ $has_run -eq 1 ]; then
                echo -e "${GREEN}→ Found: .run installer inside${NC}"
                echo -e "${BLUE}→ Using: monitor_run_installer.sh${NC}"
                echo ""
                if [ -n "$opts" ]; then
                    exec "${SCRIPT_DIR}/scripts/monitor_run_installer.sh" "$input" "$opts"
                else
                    exec "${SCRIPT_DIR}/scripts/monitor_run_installer.sh" "$input"
                fi
            elif [ $has_install_script -eq 1 ]; then
                echo -e "${GREEN}→ Found: Shell install script${NC}"
                echo -e "${BLUE}→ Using: monitor_install.sh${NC}"
                echo ""
                if [ -n "$opts" ]; then
                    exec "${SCRIPT_DIR}/scripts/monitor_install.sh" "$input" "$opts"
                else
                    exec "${SCRIPT_DIR}/scripts/monitor_install.sh" "$input"
                fi
            else
                # Default to regular monitor
                echo -e "${YELLOW}→ No obvious installer detected${NC}"
                echo -e "${BLUE}→ Using: monitor_install.sh (will extract and analyze)${NC}"
                echo ""
                if [ -n "$opts" ]; then
                    exec "${SCRIPT_DIR}/scripts/monitor_install.sh" "$input" "$opts"
                else
                    exec "${SCRIPT_DIR}/scripts/monitor_install.sh" "$input"
                fi
            fi
            ;;

        *.run)
            echo -e "${GREEN}→ Detected: .run installer${NC}"
            echo -e "${YELLOW}→ Note: This is already extracted${NC}"
            echo -e "${BLUE}→ Run directly with monitoring...${NC}"
            echo ""
            # TODO: Could add direct .run monitoring
            echo "To monitor this .run file, you can:"
            echo "  1. Create a tar.gz: tar czf installer.tar.gz $(basename "$input")"
            echo "  2. Then run: ./install_monitor.sh installer.tar.gz"
            exit 0
            ;;

        *)
            echo -e "${YELLOW}→ Unknown file type: ${file_type}${NC}"
            echo "Supported formats: .tar.gz, .tar.bz2, .tgz, .tbz"
            echo "For directories: provide the installation path"
            exit 1
            ;;
    esac
}

# Main execution
print_banner

if [ -z "$INPUT" ]; then
    print_help
    exit 0
fi

if [ "$INPUT" = "-h" ] || [ "$INPUT" = "--help" ]; then
    print_help
    exit 0
fi

echo -e "${BLUE}Analyzing: ${INPUT}${NC}"
echo ""

detect_and_run "$INPUT" "$OPTIONS"
