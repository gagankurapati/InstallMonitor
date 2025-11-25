#!/bin/bash
#
# Analyze Existing Installation Script
# Use this to analyze an already-installed application
# without running the installer again
#
# Usage: ./analyze_existing_install.sh <installation_directory>
#

set -euo pipefail

INSTALL_DIR="${1:-}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/analysis_${TIMESTAMP}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_msg() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $*"
}

print_success() {
    echo -e "${GREEN}✓${NC} $*"
}

if [ -z "$INSTALL_DIR" ]; then
    echo "Usage: $0 <installation_directory>"
    echo ""
    echo "Example: $0 /opt/myapp"
    exit 1
fi

if [ ! -d "$INSTALL_DIR" ]; then
    echo "Error: Directory not found: $INSTALL_DIR"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

print_msg "Analyzing installation: $INSTALL_DIR"
print_msg "Output directory: $OUTPUT_DIR"

# Analyze directory structure
{
    echo "# Directory Structure"
    echo ""
    tree -L 3 "$INSTALL_DIR" 2>/dev/null || find "$INSTALL_DIR" -maxdepth 3 -type d | sort
} > "${OUTPUT_DIR}/directory_structure.txt"

print_success "Directory structure analyzed"

# List all files
{
    echo "# All Files in Installation"
    find "$INSTALL_DIR" -type f | sort
} > "${OUTPUT_DIR}/all_files.txt"

print_success "File list created ($(wc -l < "${OUTPUT_DIR}/all_files.txt") files)"

# Analyze file types
{
    echo "# File Types Distribution"
    find "$INSTALL_DIR" -type f | xargs file | cut -d: -f2 | sort | uniq -c | sort -rn
} > "${OUTPUT_DIR}/file_types.txt"

print_success "File types analyzed"

# Find executables
{
    echo "# Executable Files"
    find "$INSTALL_DIR" -type f -executable
} > "${OUTPUT_DIR}/executables.txt"

print_success "Executables found ($(wc -l < "${OUTPUT_DIR}/executables.txt") files)"

# Find libraries
{
    echo "# Shared Libraries"
    find "$INSTALL_DIR" -type f -name "*.so*" -o -name "*.a"
} > "${OUTPUT_DIR}/libraries.txt"

print_success "Libraries found ($(wc -l < "${OUTPUT_DIR}/libraries.txt") files)"

# Find scripts
{
    echo "# Shell Scripts"
    find "$INSTALL_DIR" -type f -name "*.sh" -o -name "*.bash"
    echo ""
    echo "# Python Scripts"
    find "$INSTALL_DIR" -type f -name "*.py"
} > "${OUTPUT_DIR}/scripts.txt"

print_success "Scripts analyzed"

# Analyze symbolic links
{
    echo "# Symbolic Links"
    find "$INSTALL_DIR" -type l -ls
} > "${OUTPUT_DIR}/symlinks.txt"

print_success "Symbolic links analyzed"

# Check for environment setup scripts
{
    echo "# Environment Setup Scripts"
    find "$INSTALL_DIR" -type f \( -name "*env*" -o -name "setup*" -o -name "activate*" \) -exec echo {} \; -exec head -20 {} \; -exec echo "---" \;
} > "${OUTPUT_DIR}/env_scripts.txt"

print_success "Environment scripts found"

# Scan for hardcoded paths
{
    echo "# Files with Hardcoded Paths"
    echo "Scanning for absolute paths in executables and scripts..."
    for file in $(cat "${OUTPUT_DIR}/executables.txt" "${OUTPUT_DIR}/scripts.txt"); do
        if [ -f "$file" ]; then
            if strings "$file" 2>/dev/null | grep -E "^/" | grep -v "^/usr/bin" | grep -q "$INSTALL_DIR"; then
                echo ""
                echo "File: $file"
                strings "$file" 2>/dev/null | grep "$INSTALL_DIR" | head -10
            fi
        fi
    done
} > "${OUTPUT_DIR}/hardcoded_paths.txt"

print_success "Hardcoded paths analyzed"

# Generate InstallBuilder mapping
{
    echo "# InstallBuilder File Mapping"
    echo ""
    echo "## Suggested InstallBuilder Structure"
    echo ""

    # Detect common directory patterns
    if [ -d "$INSTALL_DIR/bin" ]; then
        echo "<folder>"
        echo "    <description>Program Executables</description>"
        echo "    <destination>\${installdir}/bin</destination>"
        echo "    <name>binfiles</name>"
        echo "    <platforms>all</platforms>"
        echo "    <distributionFileList>"
        find "$INSTALL_DIR/bin" -type f -printf "        <distributionFile><origin>%p</origin></distributionFile>\n"
        echo "    </distributionFileList>"
        echo "</folder>"
        echo ""
    fi

    if [ -d "$INSTALL_DIR/lib" ]; then
        echo "<folder>"
        echo "    <description>Shared Libraries</description>"
        echo "    <destination>\${installdir}/lib</destination>"
        echo "    <name>libfiles</name>"
        echo "    <platforms>all</platforms>"
        echo "    <distributionFileList>"
        find "$INSTALL_DIR/lib" -type f -printf "        <distributionFile><origin>%p</origin></distributionFile>\n" | head -20
        if [ $(find "$INSTALL_DIR/lib" -type f | wc -l) -gt 20 ]; then
            echo "        <!-- ... $(( $(find "$INSTALL_DIR/lib" -type f | wc -l) - 20 )) more files -->"
        fi
        echo "    </distributionFileList>"
        echo "</folder>"
        echo ""
    fi

    if [ -d "$INSTALL_DIR/share" ]; then
        echo "<folder>"
        echo "    <description>Data Files</description>"
        echo "    <destination>\${installdir}/share</destination>"
        echo "    <name>datafiles</name>"
        echo "    <platforms>all</platforms>"
        echo "</folder>"
        echo ""
    fi

    # Environment variables
    echo ""
    echo "## Environment Variables to Add"
    echo ""
    echo "<postInstallationActionList>"

    if [ -d "$INSTALL_DIR/bin" ]; then
        echo "    <addEnvironmentVariable>"
        echo "        <name>PATH</name>"
        echo "        <scope>system</scope>"
        echo "        <value>\${installdir}/bin:\${env(PATH)}</value>"
        echo "    </addEnvironmentVariable>"
    fi

    if [ -d "$INSTALL_DIR/lib" ]; then
        echo "    <addEnvironmentVariable>"
        echo "        <name>LD_LIBRARY_PATH</name>"
        echo "        <scope>system</scope>"
        echo "        <value>\${installdir}/lib:\${env(LD_LIBRARY_PATH)}</value>"
        echo "    </addEnvironmentVariable>"
    fi

    echo "</postInstallationActionList>"

} > "${OUTPUT_DIR}/installbuilder_template.xml"

print_success "InstallBuilder template generated"

# Create summary report
{
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║        Installation Analysis Summary                   ║"
    echo "╚════════════════════════════════════════════════════════╝"
    echo ""
    echo "Installation Directory: $INSTALL_DIR"
    echo "Analysis Date: $(date)"
    echo ""
    echo "Statistics:"
    echo "  - Total files:       $(wc -l < "${OUTPUT_DIR}/all_files.txt")"
    echo "  - Executables:       $(wc -l < "${OUTPUT_DIR}/executables.txt")"
    echo "  - Libraries:         $(wc -l < "${OUTPUT_DIR}/libraries.txt")"
    echo "  - Symbolic links:    $(wc -l < "${OUTPUT_DIR}/symlinks.txt")"
    echo ""
    echo "Key Directories:"
    find "$INSTALL_DIR" -maxdepth 1 -type d | tail -n +2 | while read -r dir; do
        echo "  - $(basename "$dir")/ ($(find "$dir" -type f | wc -l) files)"
    done
    echo ""
    echo "Generated Files:"
    echo "  - Directory structure:    ${OUTPUT_DIR}/directory_structure.txt"
    echo "  - Complete file list:     ${OUTPUT_DIR}/all_files.txt"
    echo "  - Executables:            ${OUTPUT_DIR}/executables.txt"
    echo "  - Libraries:              ${OUTPUT_DIR}/libraries.txt"
    echo "  - Environment scripts:    ${OUTPUT_DIR}/env_scripts.txt"
    echo "  - InstallBuilder XML:     ${OUTPUT_DIR}/installbuilder_template.xml"
    echo ""
    echo "Next Steps:"
    echo "  1. Review ${OUTPUT_DIR}/installbuilder_template.xml"
    echo "  2. Check ${OUTPUT_DIR}/env_scripts.txt for environment setup"
    echo "  3. Examine ${OUTPUT_DIR}/hardcoded_paths.txt for path issues"
    echo "  4. Copy files to your InstallBuilder project"
    echo ""
} | tee "${OUTPUT_DIR}/SUMMARY.txt"

print_msg "Analysis complete!"
echo ""
echo "All results saved to: $OUTPUT_DIR"
