#!/bin/bash
################################################################################
# Script: 01_verify_system.sh
# Purpose: Verify Ubuntu 24.04 LTS and amdgpu driver prerequisites
# Usage: ./01_verify_system.sh
# Exit Codes:
#   0 - All checks passed
#   1 - One or more checks failed
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_${TIMESTAMP}.log"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo "  System Verification for LeRobot Setup"
    echo "=============================================="
    echo ""
    log "Starting system verification..."
    log "Log file: $LOG_FILE"
    echo ""
}

# Check Ubuntu version
check_ubuntu_version() {
    log_info "Checking Ubuntu version..."
    
    if [ ! -f /etc/lsb-release ]; then
        log_error "Cannot find /etc/lsb-release. Is this Ubuntu?"
        return 1
    fi
    
    source /etc/lsb-release
    
    log "Detected: $DISTRIB_DESCRIPTION"
    
    if [ "$DISTRIB_ID" != "Ubuntu" ]; then
        log_error "This script requires Ubuntu. Detected: $DISTRIB_ID"
        return 1
    fi
    
    if [ "$DISTRIB_RELEASE" != "24.04" ]; then
        log_error "This script requires Ubuntu 24.04 LTS. Detected: $DISTRIB_RELEASE"
        log_error "Please install Ubuntu 24.04 LTS (noble) and try again."
        return 1
    fi
    
    if [ "$DISTRIB_CODENAME" != "noble" ]; then
        log_warning "Expected codename 'noble', got '$DISTRIB_CODENAME'"
    fi
    
    log_success "Ubuntu 24.04 LTS detected"
    return 0
}

# Check kernel version
check_kernel_version() {
    log_info "Checking kernel version..."
    
    KERNEL_VERSION=$(uname -r)
    log "Detected kernel: $KERNEL_VERSION"
    
    # Extract major and minor version
    KERNEL_MAJOR=$(echo "$KERNEL_VERSION" | cut -d. -f1)
    KERNEL_MINOR=$(echo "$KERNEL_VERSION" | cut -d. -f2)
    
    # Check if kernel is 6.14 or higher (as per QuickStart.md example)
    if [ "$KERNEL_MAJOR" -lt 6 ]; then
        log_error "Kernel version too old. Expected 6.14+, got $KERNEL_VERSION"
        log_error "Please update your kernel and try again."
        return 1
    fi
    
    if [ "$KERNEL_MAJOR" -eq 6 ] && [ "$KERNEL_MINOR" -lt 14 ]; then
        log_warning "Kernel version is $KERNEL_VERSION. Recommended: 6.14+"
        log_warning "The setup may still work, but 6.14+ is recommended."
    else
        log_success "Kernel version $KERNEL_VERSION is compatible"
    fi
    
    return 0
}

# Check amdgpu driver
check_amdgpu_driver() {
    log_info "Checking amdgpu driver..."
    
    if ! lsmod | grep -q amdgpu; then
        log_warning "amdgpu driver is not currently loaded"
        log_warning ""
        log_warning "This is normal if ROCm has not been installed yet."
        log_warning "The amdgpu driver will be properly configured during ROCm installation."
        log_warning ""
        log_info "If you have an AMD Ryzen AI PC, the driver will load after ROCm installation."
        log_info "The QuickStart.md shows the driver check as verification AFTER ROCm is installed."
        return 0
    fi
    
    log_success "amdgpu driver is already loaded"
    
    # Show loaded amdgpu modules
    log_info "Loaded amdgpu-related modules:"
    lsmod | grep amdgpu | tee -a "$LOG_FILE"
    
    return 0
}

# Check user groups
check_user_groups() {
    log_info "Checking user groups (render and video)..."
    
    CURRENT_USER=$(whoami)
    USER_GROUPS=$(groups "$CURRENT_USER")
    
    MISSING_GROUPS=()
    
    if ! echo "$USER_GROUPS" | grep -q "render"; then
        MISSING_GROUPS+=("render")
    fi
    
    if ! echo "$USER_GROUPS" | grep -q "video"; then
        MISSING_GROUPS+=("video")
    fi
    
    if [ ${#MISSING_GROUPS[@]} -eq 0 ]; then
        log_success "User '$CURRENT_USER' is in both render and video groups"
        return 0
    else
        log_warning "User '$CURRENT_USER' is missing groups: ${MISSING_GROUPS[*]}"
        log_warning "These groups will be added during ROCm installation."
        log_warning "You will need to log out and back in after installation."
        return 0
    fi
}

# Check VRAM allocation (informational only)
check_vram_allocation() {
    log_info "Checking VRAM allocation (informational)..."
    
    # Try to get VRAM info from various sources
    if command -v rocm-smi &> /dev/null; then
        log_info "Using rocm-smi to check VRAM:"
        rocm-smi --showmeminfo vram 2>&1 | tee -a "$LOG_FILE" || true
    elif [ -d /sys/class/drm/card0/device ]; then
        if [ -f /sys/class/drm/card0/device/mem_info_vram_total ]; then
            VRAM_BYTES=$(cat /sys/class/drm/card0/device/mem_info_vram_total)
            VRAM_GB=$((VRAM_BYTES / 1024 / 1024 / 1024))
            log_info "Detected VRAM: ${VRAM_GB}GB"
            
            if [ "$VRAM_GB" -lt 16 ]; then
                log_warning "VRAM is less than 16GB (detected: ${VRAM_GB}GB)"
                log_warning "For optimal performance, set VRAM to 16GB+ in BIOS:"
                log_warning "  BIOS Setup => Advanced => GFX Configuration => UMA Frame buffer Size => 16GB"
                log_warning "  OR"
                log_warning "  BIOS Setup => Advanced => AMD CBS => NBIO Common Options => GFX Configuration => Dedicated Graphics Memory => 16GB"
            else
                log_success "VRAM allocation is ${VRAM_GB}GB (meets 16GB+ requirement)"
            fi
        else
            log_warning "Cannot determine VRAM allocation from sysfs"
        fi
    else
        log_warning "Cannot determine VRAM allocation (rocm-smi not installed and sysfs not available)"
        log_warning "Please ensure VRAM is set to 16GB+ in BIOS settings"
    fi
    
    return 0
}

# Check disk space
check_disk_space() {
    log_info "Checking available disk space..."
    
    AVAILABLE_GB=$(df -BG "$HOME" | tail -1 | awk '{print $4}' | sed 's/G//')
    
    log "Available space in $HOME: ${AVAILABLE_GB}GB"
    
    if [ "$AVAILABLE_GB" -lt 20 ]; then
        log_error "Insufficient disk space. Need at least 20GB, have ${AVAILABLE_GB}GB"
        log_error "Please free up disk space and try again."
        return 1
    fi
    
    if [ "$AVAILABLE_GB" -lt 50 ]; then
        log_warning "Low disk space: ${AVAILABLE_GB}GB available"
        log_warning "Recommended: 50GB+ for comfortable development"
    else
        log_success "Sufficient disk space available: ${AVAILABLE_GB}GB"
    fi
    
    return 0
}

# Main verification function
main() {
    print_header
    
    local FAILED_CHECKS=0
    
    # Run all checks
    check_ubuntu_version || ((FAILED_CHECKS++))
    echo ""
    
    check_kernel_version || ((FAILED_CHECKS++))
    echo ""
    
    check_amdgpu_driver || true  # Informational only - driver loads after ROCm install
    echo ""
    
    check_user_groups || true  # Don't fail on this
    echo ""
    
    check_vram_allocation || true  # Informational only
    echo ""
    
    check_disk_space || ((FAILED_CHECKS++))
    echo ""
    
    # Print summary
    echo "=============================================="
    echo "  Verification Summary"
    echo "=============================================="
    echo ""
    
    if [ $FAILED_CHECKS -eq 0 ]; then
        log_success "All critical checks passed!"
        log_success "System is ready for ROCm and LeRobot installation."
        echo ""
        log_info "Next step: Run ./02_install_rocm.sh"
        echo ""
        return 0
    else
        log_error "Failed $FAILED_CHECKS critical check(s)"
        log_error "Please fix the issues above before proceeding."
        echo ""
        log_error "Common fixes:"
        log_error "  - Ensure you're running Ubuntu 24.04 LTS"
        log_error "  - Ensure you have an AMD Ryzen AI PC"
        log_error "  - Update your kernel if needed"
        log_error "  - Free up disk space if needed"
        echo ""
        return 1
    fi
}

# Run main function
main
exit $?