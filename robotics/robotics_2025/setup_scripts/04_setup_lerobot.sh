#!/bin/bash
################################################################################
# Script: 04_setup_lerobot.sh
# Purpose: Clone and setup LeRobot v0.4.1 development environment
# Usage: ./04_setup_lerobot.sh
# Exit Codes:
#   0 - Setup successful
#   1 - Setup failed
#   2 - Already configured
################################################################################

set -euo pipefail

# Script metadata
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/${SCRIPT_NAME%.sh}_${TIMESTAMP}.log"
MARKER_FILE="${LOG_DIR}/.step_04_complete"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONDA_ENV_NAME="lerobot"
LEROBOT_VERSION="v0.4.1"
LEROBOT_REPO_URL="https://github.com/huggingface/lerobot.git"
LEROBOT_DIR="$HOME/lerobot"
FFMPEG_VERSION="7.1.1"

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
    echo "  LeRobot v0.4.1 Setup"
    echo "=============================================="
    echo ""
    log "Starting LeRobot setup..."
    log "Log file: $LOG_FILE"
    echo ""
}

# Check if already configured
check_existing_setup() {
    log_info "Checking for existing LeRobot setup..."
    
    if [ -f "$MARKER_FILE" ]; then
        log_warning "LeRobot setup marker found: $MARKER_FILE"
        
        # Check if lerobot is installed
        if command -v conda &> /dev/null; then
            source "$(conda info --base)/etc/profile.d/conda.sh"
            conda activate "$CONDA_ENV_NAME" 2>/dev/null || true
            
            if python -c "import lerobot" 2>/dev/null; then
                LEROBOT_VER=$(pip list | grep lerobot | awk '{print $2}')
                log "Installed LeRobot version: $LEROBOT_VER"
                
                if [ "$LEROBOT_VER" == "0.4.1" ]; then
                    log_success "LeRobot v0.4.1 is already installed!"
                    log_info "If you need to reinstall, remove: $MARKER_FILE"
                    return 2
                else
                    log_warning "LeRobot version mismatch. Expected 0.4.1, got $LEROBOT_VER"
                fi
            fi
        fi
    fi
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if conda is installed
    if ! command -v conda &> /dev/null; then
        log_error "Conda is not installed"
        log_error "Please run ./03_setup_pytorch.sh first"
        return 1
    fi
    
    log_success "Conda is installed"
    
    # Check if lerobot conda environment exists
    if ! conda env list | grep -q "^${CONDA_ENV_NAME} "; then
        log_error "Conda environment '$CONDA_ENV_NAME' does not exist"
        log_error "Please run ./03_setup_pytorch.sh first"
        return 1
    fi
    
    log_success "Conda environment '$CONDA_ENV_NAME' exists"
    
    # Check if PyTorch is installed in the environment
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    if ! python -c "import torch" 2>/dev/null; then
        log_error "PyTorch is not installed in '$CONDA_ENV_NAME' environment"
        log_error "Please run ./03_setup_pytorch.sh first"
        return 1
    fi
    
    log_success "PyTorch is installed"
    
    # Check if git is installed
    if ! command -v git &> /dev/null; then
        log_error "Git is not installed"
        log_error "Please install git: sudo apt install git"
        return 1
    fi
    
    log_success "Git is installed"
    
    return 0
}

# Install ffmpeg via conda
install_ffmpeg() {
    log_info "Installing ffmpeg ${FFMPEG_VERSION} via conda-forge..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Check if ffmpeg is already installed
    if conda list | grep -q "^ffmpeg "; then
        INSTALLED_FFMPEG=$(conda list | grep "^ffmpeg " | awk '{print $2}')
        log_info "ffmpeg is already installed: version $INSTALLED_FFMPEG"
        
        if [ "$INSTALLED_FFMPEG" == "$FFMPEG_VERSION" ]; then
            log_success "ffmpeg ${FFMPEG_VERSION} is already installed"
            return 0
        else
            log_warning "ffmpeg version mismatch. Installed: $INSTALLED_FFMPEG, Expected: $FFMPEG_VERSION"
            log_info "Proceeding with installation (may upgrade/downgrade)"
        fi
    fi
    
    log "Running: conda install ffmpeg=${FFMPEG_VERSION} -c conda-forge -y"
    
    if ! conda install "ffmpeg=${FFMPEG_VERSION}" -c conda-forge -y 2>&1 | tee -a "$LOG_FILE"; then
        log_error "ffmpeg installation failed"
        return 1
    fi
    
    log_success "ffmpeg ${FFMPEG_VERSION} installed"
    
    return 0
}

# Clone LeRobot repository
clone_lerobot() {
    log_info "Cloning LeRobot repository..."
    
    # Check if directory already exists
    if [ -d "$LEROBOT_DIR" ]; then
        log_warning "Directory $LEROBOT_DIR already exists"
        
        # Check if it's a git repository
        if [ -d "$LEROBOT_DIR/.git" ]; then
            log_info "Existing directory is a git repository"
            
            # Check remote URL
            cd "$LEROBOT_DIR"
            REMOTE_URL=$(git remote get-url origin 2>/dev/null || echo "")
            
            if [ "$REMOTE_URL" == "$LEROBOT_REPO_URL" ]; then
                log_success "Repository already cloned with correct URL"
                return 0
            else
                log_warning "Repository has different remote URL: $REMOTE_URL"
                log_warning "Expected: $LEROBOT_REPO_URL"
                log_error "Please remove $LEROBOT_DIR and try again"
                return 1
            fi
        else
            log_error "Directory exists but is not a git repository"
            log_error "Please remove $LEROBOT_DIR and try again"
            return 1
        fi
    fi
    
    # Clone the repository
    log "Cloning from: $LEROBOT_REPO_URL"
    log "Destination: $LEROBOT_DIR"
    
    if ! git clone "$LEROBOT_REPO_URL" "$LEROBOT_DIR" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to clone LeRobot repository"
        return 1
    fi
    
    log_success "LeRobot repository cloned"
    
    return 0
}

# Checkout specific version
checkout_version() {
    log_info "Checking out LeRobot ${LEROBOT_VERSION}..."
    
    cd "$LEROBOT_DIR"
    
    # Check current branch/tag
    CURRENT_REF=$(git describe --tags --exact-match 2>/dev/null || git rev-parse --abbrev-ref HEAD)
    log "Current ref: $CURRENT_REF"
    
    if [ "$CURRENT_REF" == "$LEROBOT_VERSION" ]; then
        log_success "Already on ${LEROBOT_VERSION}"
        return 0
    fi
    
    # Fetch tags
    log "Fetching tags..."
    if ! git fetch --tags 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to fetch tags"
        return 1
    fi
    
    # Check if tag exists
    if ! git tag | grep -q "^${LEROBOT_VERSION}$"; then
        log_error "Tag ${LEROBOT_VERSION} does not exist"
        log_error "Available tags:"
        git tag | tail -10 | tee -a "$LOG_FILE"
        return 1
    fi
    
    # Checkout the version
    log "Running: git checkout -b ${LEROBOT_VERSION} ${LEROBOT_VERSION}"
    
    if ! git checkout -b "$LEROBOT_VERSION" "$LEROBOT_VERSION" 2>&1 | tee -a "$LOG_FILE"; then
        # Branch might already exist, try checking out directly
        log_warning "Branch creation failed, trying direct checkout..."
        if ! git checkout "$LEROBOT_VERSION" 2>&1 | tee -a "$LOG_FILE"; then
            log_error "Failed to checkout ${LEROBOT_VERSION}"
            return 1
        fi
    fi
    
    log_success "Checked out ${LEROBOT_VERSION}"
    
    return 0
}

# Install LeRobot in editable mode
install_lerobot() {
    log_info "Installing LeRobot in editable mode..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    cd "$LEROBOT_DIR"
    
    log "Running: pip install -e ."
    log_warning "This may take several minutes..."
    
    if ! pip install -e . 2>&1 | tee -a "$LOG_FILE"; then
        log_error "LeRobot installation failed"
        return 1
    fi
    
    log_success "LeRobot installed in editable mode"
    
    return 0
}

# Install feetech servo SDK
install_feetech() {
    log_info "Installing feetech servo SDK for SO-ARM101..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    log "Running: pip install 'lerobot[feetech]'"
    
    if ! pip install 'lerobot[feetech]' 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Feetech servo SDK installation failed"
        return 1
    fi
    
    log_success "Feetech servo SDK installed"
    
    return 0
}

# Verify installation
verify_installation() {
    log_info "Verifying LeRobot installation..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Check if lerobot can be imported
    log_info "Testing LeRobot import..."
    if ! python -c "import lerobot" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to import lerobot"
        return 1
    fi
    
    log_success "LeRobot import successful"
    
    # Check installed version
    log_info "Checking installed packages:"
    pip list | grep lerobot | tee -a "$LOG_FILE"
    
    LEROBOT_VER=$(pip list | grep "^lerobot " | awk '{print $2}')
    LEROBOT_PATH=$(pip list | grep "^lerobot " | awk '{print $3}')
    
    log "LeRobot version: $LEROBOT_VER"
    log "LeRobot path: $LEROBOT_PATH"
    
    if [ "$LEROBOT_VER" != "0.4.1" ]; then
        log_error "LeRobot version mismatch. Expected 0.4.1, got $LEROBOT_VER"
        return 1
    fi
    
    log_success "LeRobot v0.4.1 verified"
    
    return 0
}

# Create completion marker
create_marker() {
    log_info "Creating completion marker..."
    echo "LeRobot ${LEROBOT_VERSION} installed on $(date)" > "$MARKER_FILE"
    echo "Installation directory: $LEROBOT_DIR" >> "$MARKER_FILE"
    log_success "Marker created: $MARKER_FILE"
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=============================================="
    log_success "LeRobot Setup Complete!"
    echo "=============================================="
    echo ""
    log_info "LeRobot v0.4.1 is installed at: $LEROBOT_DIR"
    echo ""
    log_info "To use LeRobot:"
    log_info "  1. conda activate $CONDA_ENV_NAME"
    log_info "  2. cd $LEROBOT_DIR"
    log_info "  3. Follow the LeRobot documentation for:"
    log_info "     - Calibration"
    log_info "     - Teleoperation"
    log_info "     - Creating datasets"
    log_info "     - Inference evaluation with SO-101 ARM"
    echo ""
    log_info "Documentation: https://huggingface.co/docs/lerobot/index"
    echo ""
    log_success "Edge development environment is ready!"
    echo ""
    log_info "For training environment setup, refer to:"
    log_info "  robotics/robotics_2025/training-models-on-rocm.ipynb"
    echo ""
}

# Main setup function
main() {
    print_header
    
    # Check if already configured
    if check_existing_setup; then
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 2 ]; then
            echo ""
            log_info "LeRobot is already configured!"
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
    
    # Install ffmpeg
    if ! install_ffmpeg; then
        log_error "ffmpeg installation failed"
        exit 1
    fi
    
    echo ""
    
    # Clone LeRobot repository
    if ! clone_lerobot; then
        log_error "Failed to clone LeRobot repository"
        exit 1
    fi
    
    echo ""
    
    # Checkout specific version
    if ! checkout_version; then
        log_error "Failed to checkout ${LEROBOT_VERSION}"
        exit 1
    fi
    
    echo ""
    
    # Install LeRobot
    if ! install_lerobot; then
        log_error "LeRobot installation failed"
        exit 1
    fi
    
    echo ""
    
    # Install feetech servo SDK
    if ! install_feetech; then
        log_error "Feetech servo SDK installation failed"
        exit 1
    fi
    
    echo ""
    
    # Verify installation
    if ! verify_installation; then
        log_error "LeRobot verification failed"
        exit 1
    fi
    
    echo ""
    
    # Create completion marker
    create_marker
    
    # Print next steps
    print_next_steps
    
    exit 0
}

# Run main function
main