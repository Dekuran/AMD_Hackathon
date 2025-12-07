#!/bin/bash
################################################################################
# Script: 02_install_rocm.sh
# Purpose: Install ROCm 6.3.x for AMD Ryzen AI PC
# Usage: ./02_install_rocm.sh
# Exit Codes:
#   0 - Installation successful (reboot required)
#   1 - Installation failed
#   2 - Already installed (no action needed)
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_${TIMESTAMP}.log"
MARKER_FILE="${LOG_DIR}/.step_02_complete"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ROCm version to install
ROCM_VERSION="6.3.4"
ROCM_BUILD="6.3.60304-1"
AMDGPU_INSTALL_DEB="amdgpu-install_${ROCM_BUILD}_all.deb"
AMDGPU_INSTALL_URL="https://repo.radeon.com/amdgpu-install/${ROCM_VERSION}/ubuntu/noble/${AMDGPU_INSTALL_DEB}"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging functions
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

# Print header
print_header() {
    echo ""
    echo "=============================================="
    echo "  ROCm 6.3.x Installation"
    echo "=============================================="
    echo ""
    log "Starting ROCm installation..."
    log "Log file: $LOG_FILE"
    echo ""
}

# Check if already installed
check_existing_installation() {
    log_info "Checking for existing ROCm installation..."
    
    if [ -f "$MARKER_FILE" ]; then
        log_warning "ROCm installation marker found: $MARKER_FILE"
        log_warning "This indicates ROCm was previously installed by this script."
    fi
    
    if command -v rocm-smi &> /dev/null; then
        log_info "rocm-smi command found. Checking version..."
        INSTALLED_VERSION=$(rocm-smi --version 2>&1 | grep -oP 'ROCm version: \K[0-9.]+' || echo "unknown")
        log "Installed ROCm version: $INSTALLED_VERSION"
        
        if [[ "$INSTALLED_VERSION" == "6.3"* ]]; then
            log_success "ROCm 6.3.x is already installed!"
            log_info "If you need to reinstall, remove the marker file: $MARKER_FILE"
            return 2
        else
            log_warning "ROCm is installed but version is $INSTALLED_VERSION (expected 6.3.x)"
            log_warning "Proceeding with installation (may upgrade/reinstall)"
        fi
    fi
    
    if dpkg -l | grep -q amdgpu-install; then
        log_info "amdgpu-install package is already installed"
        if dpkg -l | grep -q rocm; then
            log_warning "Some ROCm packages are installed. Proceeding with installation."
        fi
    fi
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running Ubuntu 24.04
    if [ ! -f /etc/lsb-release ]; then
        log_error "Cannot find /etc/lsb-release. Is this Ubuntu?"
        return 1
    fi
    
    source /etc/lsb-release
    
    if [ "$DISTRIB_RELEASE" != "24.04" ]; then
        log_error "This script requires Ubuntu 24.04. Detected: $DISTRIB_RELEASE"
        return 1
    fi
    
    log_success "Ubuntu 24.04 confirmed"
    
    # Check disk space (need at least 10GB)
    AVAILABLE_GB=$(df -BG /tmp | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAILABLE_GB" -lt 10 ]; then
        log_error "Insufficient disk space in /tmp. Need 10GB, have ${AVAILABLE_GB}GB"
        return 1
    fi
    
    log_success "Sufficient disk space available"
    
    # Check internet connectivity
    if ! ping -c 1 repo.radeon.com &> /dev/null; then
        log_error "Cannot reach repo.radeon.com. Check internet connection."
        return 1
    fi
    
    log_success "Internet connectivity confirmed"
    
    return 0
}

# Update system packages
update_system() {
    log_info "Updating system packages..."
    
    sudo apt update 2>&1 | tee -a "$LOG_FILE"
    
    log_info "Installing required kernel headers and modules..."
    sudo apt install -y "linux-headers-$(uname -r)" "linux-modules-extra-$(uname -r)" 2>&1 | tee -a "$LOG_FILE"
    
    log_info "Installing Python setuptools and wheel..."
    sudo apt install -y python3-setuptools python3-wheel 2>&1 | tee -a "$LOG_FILE"
    
    log_success "System packages updated"
    return 0
}

# Add user to render and video groups
add_user_to_groups() {
    log_info "Adding user to render and video groups..."
    
    CURRENT_USER=$(whoami)
    
    # Add to render group
    if ! groups "$CURRENT_USER" | grep -q render; then
        sudo usermod -a -G render "$CURRENT_USER"
        log_success "Added $CURRENT_USER to render group"
    else
        log_info "User $CURRENT_USER already in render group"
    fi
    
    # Add to video group
    if ! groups "$CURRENT_USER" | grep -q video; then
        sudo usermod -a -G video "$CURRENT_USER"
        log_success "Added $CURRENT_USER to video group"
    else
        log_info "User $CURRENT_USER already in video group"
    fi
    
    log_warning "Note: Group changes will take effect after logout/login or reboot"
    
    return 0
}

# Download amdgpu-install package
download_amdgpu_install() {
    log_info "Downloading amdgpu-install package..."
    
    cd /tmp
    
    # Remove old download if exists
    if [ -f "$AMDGPU_INSTALL_DEB" ]; then
        log_info "Removing old download..."
        rm -f "$AMDGPU_INSTALL_DEB"
    fi
    
    log "Downloading from: $AMDGPU_INSTALL_URL"
    
    if ! wget "$AMDGPU_INSTALL_URL" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to download amdgpu-install package"
        return 1
    fi
    
    if [ ! -f "$AMDGPU_INSTALL_DEB" ]; then
        log_error "Download completed but file not found: $AMDGPU_INSTALL_DEB"
        return 1
    fi
    
    log_success "Downloaded $AMDGPU_INSTALL_DEB"
    
    # Verify it's a valid deb package
    if ! file "$AMDGPU_INSTALL_DEB" | grep -q "Debian binary package"; then
        log_error "Downloaded file is not a valid Debian package"
        return 1
    fi
    
    log_success "Package verification passed"
    
    return 0
}

# Install amdgpu-install package
install_amdgpu_install() {
    log_info "Installing amdgpu-install package..."
    
    cd /tmp
    
    if ! sudo apt install -y "./$AMDGPU_INSTALL_DEB" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to install amdgpu-install package"
        return 1
    fi
    
    log_success "amdgpu-install package installed"
    
    return 0
}

# Install ROCm using amdgpu-install
install_rocm() {
    log_info "Installing ROCm 6.3.x (this may take several minutes)..."
    
    # Run amdgpu-install with rocm usecase and --no-dkms flag
    # NOTE: amdgpu-install is run WITHOUT sudo as per QuickStart.md line 80
    log "Running: amdgpu-install -y --usecase=rocm --no-dkms"
    
    if ! amdgpu-install -y --usecase=rocm --no-dkms 2>&1 | tee -a "$LOG_FILE"; then
        log_error "ROCm installation failed"
        log_error "Check the log file for details: $LOG_FILE"
        return 1
    fi
    
    log_success "ROCm installation completed"
    
    return 0
}

# Verify installation
verify_installation() {
    log_info "Verifying ROCm installation..."
    
    # Check if rocm-smi is available
    if ! command -v rocm-smi &> /dev/null; then
        log_error "rocm-smi command not found after installation"
        log_error "Installation may have failed"
        return 1
    fi
    
    log_success "rocm-smi command is available"
    
    # Try to get ROCm version
    if rocm-smi --version 2>&1 | tee -a "$LOG_FILE"; then
        log_success "ROCm tools are functional"
    else
        log_warning "rocm-smi returned an error (may be normal before reboot)"
    fi
    
    return 0
}

# Create completion marker
create_marker() {
    log_info "Creating completion marker..."
    echo "ROCm ${ROCM_VERSION} installed on $(date)" > "$MARKER_FILE"
    log_success "Marker created: $MARKER_FILE"
}

# Prompt for reboot
prompt_reboot() {
    echo ""
    echo "=============================================="
    log_warning "REBOOT REQUIRED"
    echo "=============================================="
    echo ""
    log_warning "ROCm installation is complete, but a system reboot is required"
    log_warning "for the changes to take effect."
    echo ""
    log_info "After rebooting:"
    log_info "  1. Log back in"
    log_info "  2. Run: ./03_setup_pytorch.sh"
    echo ""
    
    read -p "Do you want to reboot now? (y/N): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "User chose to reboot now"
        log "Rebooting in 5 seconds... (Ctrl+C to cancel)"
        sleep 5
        sudo reboot
    else
        log "User chose to reboot later"
        log_warning "Remember to reboot before continuing with the next step!"
    fi
}

# Main installation function
main() {
    print_header
    
    # Check if already installed
    if check_existing_installation; then
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 2 ]; then
            echo ""
            log_info "No installation needed. Proceed to next step: ./03_setup_pytorch.sh"
            echo ""
            exit 2
        fi
    fi
    
    echo ""
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    echo ""
    
    # Update system
    if ! update_system; then
        log_error "System update failed"
        exit 1
    fi
    
    echo ""
    
    # Add user to groups
    if ! add_user_to_groups; then
        log_error "Failed to add user to groups"
        exit 1
    fi
    
    echo ""
    
    # Download amdgpu-install
    if ! download_amdgpu_install; then
        log_error "Download failed"
        exit 1
    fi
    
    echo ""
    
    # Install amdgpu-install package
    if ! install_amdgpu_install; then
        log_error "amdgpu-install package installation failed"
        exit 1
    fi
    
    echo ""
    
    # Install ROCm
    if ! install_rocm; then
        log_error "ROCm installation failed"
        exit 1
    fi
    
    echo ""
    
    # Verify installation
    if ! verify_installation; then
        log_warning "Verification had issues, but installation may still be successful"
        log_warning "Reboot and check if ROCm works properly"
    fi
    
    echo ""
    
    # Create completion marker
    create_marker
    
    echo ""
    echo "=============================================="
    log_success "ROCm Installation Complete!"
    echo "=============================================="
    echo ""
    
    # Prompt for reboot
    prompt_reboot
    
    exit 0
}

# Run main function
main