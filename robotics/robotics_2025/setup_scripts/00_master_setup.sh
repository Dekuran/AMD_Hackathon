#!/bin/bash
################################################################################
# Script: 00_master_setup.sh
# Purpose: Master orchestration script for LeRobot setup on AMD Ryzen AI PC
# Usage: ./00_master_setup.sh
# Exit Codes:
#   0 - All steps completed successfully
#   1 - A step failed
#   3 - Reboot required (resume after reboot)
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
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# State markers
MARKER_01="${LOG_DIR}/.step_01_complete"
MARKER_02="${LOG_DIR}/.step_02_complete"
MARKER_03="${LOG_DIR}/.step_03_complete"
MARKER_04="${LOG_DIR}/.step_04_complete"
MARKER_MASTER="${LOG_DIR}/.master_setup_complete"

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

log_step() {
    echo -e "${CYAN}${BOLD}[STEP]${NC} $*" | tee -a "$LOG_FILE"
}

# Print banner
print_banner() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║     LeRobot Setup for AMD Ryzen AI PC with ROCm           ║"
    echo "║                                                            ║"
    echo "║     Master Setup Script - Automated Installation          ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log "Master setup started"
    log "Log file: $LOG_FILE"
    echo ""
}

# Check if script exists and is executable
check_script() {
    local script_path="$1"
    local script_name=$(basename "$script_path")
    
    if [ ! -f "$script_path" ]; then
        log_error "Script not found: $script_path"
        return 1
    fi
    
    if [ ! -x "$script_path" ]; then
        log_warning "Script is not executable: $script_name"
        log_info "Making script executable..."
        chmod +x "$script_path"
    fi
    
    return 0
}

# Run a setup step
run_step() {
    local step_num="$1"
    local step_name="$2"
    local script_path="$3"
    local marker_file="$4"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_step "Step ${step_num}: ${step_name}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Check if already completed
    if [ -f "$marker_file" ]; then
        log_info "Step ${step_num} already completed (marker found)"
        log_info "Skipping to next step..."
        return 0
    fi
    
    # Check if script exists
    if ! check_script "$script_path"; then
        log_error "Cannot proceed with step ${step_num}"
        return 1
    fi
    
    # Run the script
    log "Executing: $script_path"
    
    if "$script_path"; then
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            log_success "Step ${step_num} completed successfully"
            return 0
        elif [ $EXIT_CODE -eq 2 ]; then
            log_info "Step ${step_num} already configured"
            return 0
        else
            log_error "Step ${step_num} failed with exit code $EXIT_CODE"
            return 1
        fi
    else
        EXIT_CODE=$?
        log_error "Step ${step_num} failed with exit code $EXIT_CODE"
        return 1
    fi
}

# Check overall progress
check_progress() {
    log_info "Checking setup progress..."
    
    local completed=0
    local total=4
    
    [ -f "$MARKER_01" ] && ((completed++)) && log_success "✓ Step 1: System verification"
    [ ! -f "$MARKER_01" ] && log_info "○ Step 1: System verification - Pending"
    
    [ -f "$MARKER_02" ] && ((completed++)) && log_success "✓ Step 2: ROCm installation"
    [ ! -f "$MARKER_02" ] && log_info "○ Step 2: ROCm installation - Pending"
    
    [ -f "$MARKER_03" ] && ((completed++)) && log_success "✓ Step 3: PyTorch setup"
    [ ! -f "$MARKER_03" ] && log_info "○ Step 3: PyTorch setup - Pending"
    
    [ -f "$MARKER_04" ] && ((completed++)) && log_success "✓ Step 4: LeRobot setup"
    [ ! -f "$MARKER_04" ] && log_info "○ Step 4: LeRobot setup - Pending"
    
    echo ""
    log_info "Progress: ${completed}/${total} steps completed"
    echo ""
    
    if [ $completed -eq $total ]; then
        return 0
    else
        return 1
    fi
}

# Handle reboot requirement
handle_reboot() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║                   REBOOT REQUIRED                          ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    log_warning "ROCm installation requires a system reboot"
    echo ""
    log_info "After rebooting:"
    log_info "  1. Log back in"
    log_info "  2. cd $(pwd)"
    log_info "  3. Run: ./00_master_setup.sh"
    log_info ""
    log_info "The script will automatically resume from Step 3"
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
        log_warning "Remember to reboot and re-run this script!"
        exit 3
    fi
}

# Print final summary
print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║            SETUP COMPLETED SUCCESSFULLY! 🎉                ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_success "All setup steps completed successfully!"
    echo ""
    
    log_info "Summary:"
    log_success "  ✓ Ubuntu 24.04 LTS verified"
    log_success "  ✓ ROCm 6.3.x installed"
    log_success "  ✓ PyTorch 2.7.1 with ROCm configured"
    log_success "  ✓ LeRobot v0.4.1 installed"
    echo ""
    
    log_info "Your edge development environment is ready!"
    echo ""
    
    log_info "To start using LeRobot:"
    log_info "  1. conda activate lerobot"
    log_info "  2. cd ~/lerobot"
    log_info "  3. Follow the LeRobot documentation"
    echo ""
    
    log_info "Documentation:"
    log_info "  • LeRobot: https://huggingface.co/docs/lerobot/index"
    log_info "  • QuickStart: robotics/robotics_2025/QuickStart.md"
    log_info "  • Training: robotics/robotics_2025/training-models-on-rocm.ipynb"
    echo ""
    
    log_info "Log files are saved in: $LOG_DIR"
    echo ""
}

# Main orchestration function
main() {
    print_banner
    
    # Check if already completed
    if [ -f "$MARKER_MASTER" ]; then
        log_warning "Master setup already completed!"
        log_info "Marker file: $MARKER_MASTER"
        echo ""
        
        read -p "Do you want to check progress and continue anyway? (y/N): " -n 1 -r
        echo ""
        
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "User chose to exit"
            exit 0
        fi
    fi
    
    # Check current progress
    if check_progress; then
        log_success "All steps already completed!"
        print_summary
        exit 0
    fi
    
    # Step 1: Verify System
    if [ ! -f "$MARKER_01" ]; then
        if ! run_step "1" "System Verification" "${SCRIPT_DIR}/01_verify_system.sh" "$MARKER_01"; then
            log_error "Setup failed at Step 1"
            log_error "Please fix the issues and run this script again"
            exit 1
        fi
    fi
    
    # Step 2: Install ROCm
    if [ ! -f "$MARKER_02" ]; then
        if ! run_step "2" "ROCm Installation" "${SCRIPT_DIR}/02_install_rocm.sh" "$MARKER_02"; then
            log_error "Setup failed at Step 2"
            log_error "Please check the logs and run this script again"
            exit 1
        fi
        
        # Check if reboot is needed
        if [ -f "$MARKER_02" ]; then
            # ROCm was just installed, reboot is required
            handle_reboot
            # If we reach here, user chose not to reboot now
            exit 3
        fi
    fi
    
    # Step 3: Setup PyTorch
    if [ ! -f "$MARKER_03" ]; then
        if ! run_step "3" "PyTorch Setup" "${SCRIPT_DIR}/03_setup_pytorch.sh" "$MARKER_03"; then
            log_error "Setup failed at Step 3"
            log_error "Please check the logs and run this script again"
            exit 1
        fi
    fi
    
    # Step 4: Setup LeRobot
    if [ ! -f "$MARKER_04" ]; then
        if ! run_step "4" "LeRobot Setup" "${SCRIPT_DIR}/04_setup_lerobot.sh" "$MARKER_04"; then
            log_error "Setup failed at Step 4"
            log_error "Please check the logs and run this script again"
            exit 1
        fi
    fi
    
    # Create master completion marker
    echo "Master setup completed on $(date)" > "$MARKER_MASTER"
    
    # Print final summary
    print_summary
    
    exit 0
}

# Run main function
main