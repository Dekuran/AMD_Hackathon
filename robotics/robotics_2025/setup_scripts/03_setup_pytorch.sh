#!/bin/bash
################################################################################
# Script: 03_setup_pytorch.sh
# Purpose: Setup conda environment and install PyTorch 2.7.1 with ROCm 6.3
# Usage: ./03_setup_pytorch.sh
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
MARKER_FILE="${LOG_DIR}/.step_03_complete"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONDA_ENV_NAME="lerobot"
PYTHON_VERSION="3.10"
PYTORCH_VERSION="2.7.1"
TORCHVISION_VERSION="0.22.1"
TORCHAUDIO_VERSION="2.7.1"
ROCM_VERSION="6.3"
HSA_OVERRIDE_VALUE="11.0.0"

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
    echo "  PyTorch with ROCm Setup"
    echo "=============================================="
    echo ""
    log "Starting PyTorch setup..."
    log "Log file: $LOG_FILE"
    echo ""
}

# Check if already configured
check_existing_setup() {
    log_info "Checking for existing PyTorch setup..."
    
    if [ -f "$MARKER_FILE" ]; then
        log_warning "PyTorch setup marker found: $MARKER_FILE"
        
        # Check if conda env exists and has PyTorch
        if command -v conda &> /dev/null; then
            if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
                log_info "Conda environment '$CONDA_ENV_NAME' exists"
                
                # Activate and check PyTorch
                source "$(conda info --base)/etc/profile.d/conda.sh"
                conda activate "$CONDA_ENV_NAME" 2>/dev/null || true
                
                if python -c "import torch" 2>/dev/null; then
                    TORCH_VERSION=$(python -c "import torch; print(torch.__version__)" 2>/dev/null || echo "unknown")
                    log "Installed PyTorch version: $TORCH_VERSION"
                    
                    if [[ "$TORCH_VERSION" == "${PYTORCH_VERSION}+rocm"* ]]; then
                        log_success "PyTorch ${PYTORCH_VERSION} with ROCm is already installed!"
                        log_info "If you need to reinstall, remove: $MARKER_FILE"
                        return 2
                    else
                        log_warning "PyTorch version mismatch. Expected ${PYTORCH_VERSION}+rocm*, got $TORCH_VERSION"
                    fi
                fi
            fi
        fi
    fi
    
    return 0
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if ROCm is installed
    if ! command -v rocm-smi &> /dev/null; then
        log_error "ROCm is not installed or not in PATH"
        log_error "Please run ./02_install_rocm.sh first"
        return 1
    fi
    
    log_success "ROCm is installed"
    
    # Check if conda/miniconda is installed
    if ! command -v conda &> /dev/null; then
        log_error "Conda/Miniconda is not installed"
        log_error ""
        log_error "Please install Miniconda first:"
        log_error "  Visit: https://www.anaconda.com/docs/getting-started/miniconda/install"
        log_error ""
        log_error "Quick install for Linux:"
        log_error "  mkdir -p ~/miniconda3"
        log_error "  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh"
        log_error "  bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3"
        log_error "  rm ~/miniconda3/miniconda.sh"
        log_error "  ~/miniconda3/bin/conda init bash"
        log_error "  source ~/.bashrc"
        log_error ""
        return 1
    fi
    
    log_success "Conda is installed"
    
    # Get conda info
    CONDA_VERSION=$(conda --version 2>/dev/null || echo "unknown")
    log "Conda version: $CONDA_VERSION"
    
    return 0
}

# Setup HSA_OVERRIDE_GFX_VERSION in bashrc
setup_hsa_override() {
    log_info "Setting up HSA_OVERRIDE_GFX_VERSION for Ryzen AI 300 series..."
    
    BASHRC="$HOME/.bashrc"
    HSA_EXPORT_LINE="export HSA_OVERRIDE_GFX_VERSION=${HSA_OVERRIDE_VALUE}"
    
    # Check if already set
    if grep -q "HSA_OVERRIDE_GFX_VERSION" "$BASHRC"; then
        log_info "HSA_OVERRIDE_GFX_VERSION already set in $BASHRC"
        
        # Check if it's the correct value
        if grep -q "$HSA_EXPORT_LINE" "$BASHRC"; then
            log_success "HSA_OVERRIDE_GFX_VERSION is correctly set to ${HSA_OVERRIDE_VALUE}"
        else
            log_warning "HSA_OVERRIDE_GFX_VERSION is set but may have different value"
            log_warning "Current line in $BASHRC:"
            grep "HSA_OVERRIDE_GFX_VERSION" "$BASHRC" | tee -a "$LOG_FILE"
        fi
    else
        log_info "Adding HSA_OVERRIDE_GFX_VERSION to $BASHRC"
        echo "" >> "$BASHRC"
        echo "# Set HSA_OVERRIDE_GFX_VERSION for AMD Ryzen AI 300 series (gfx1100 compatible mode)" >> "$BASHRC"
        echo "$HSA_EXPORT_LINE" >> "$BASHRC"
        log_success "Added HSA_OVERRIDE_GFX_VERSION to $BASHRC"
    fi
    
    # Export for current session
    export HSA_OVERRIDE_GFX_VERSION="${HSA_OVERRIDE_VALUE}"
    log_info "HSA_OVERRIDE_GFX_VERSION set to ${HSA_OVERRIDE_VALUE} for current session"
    
    return 0
}

# Create or verify conda environment
setup_conda_env() {
    log_info "Setting up conda environment '$CONDA_ENV_NAME'..."
    
    # Initialize conda for bash
    source "$(conda info --base)/etc/profile.d/conda.sh"
    
    # Check if environment exists
    if conda env list | grep -q "^${CONDA_ENV_NAME} "; then
        log_info "Conda environment '$CONDA_ENV_NAME' already exists"
        log_info "Activating existing environment..."
    else
        log_info "Creating conda environment '$CONDA_ENV_NAME' with Python ${PYTHON_VERSION}..."
        
        if ! conda create -n "$CONDA_ENV_NAME" python="$PYTHON_VERSION" -y 2>&1 | tee -a "$LOG_FILE"; then
            log_error "Failed to create conda environment"
            return 1
        fi
        
        log_success "Conda environment created"
    fi
    
    # Activate environment
    log_info "Activating conda environment..."
    conda activate "$CONDA_ENV_NAME"
    
    if [ "$CONDA_DEFAULT_ENV" != "$CONDA_ENV_NAME" ]; then
        log_error "Failed to activate conda environment"
        return 1
    fi
    
    log_success "Conda environment '$CONDA_ENV_NAME' is active"
    
    # Show Python version
    PYTHON_VER=$(python --version 2>&1)
    log "Python version: $PYTHON_VER"
    
    return 0
}

# Install PyTorch with ROCm
install_pytorch() {
    log_info "Installing PyTorch ${PYTORCH_VERSION} with ROCm ${ROCM_VERSION}..."
    log_warning "This may take several minutes..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Install PyTorch with ROCm
    log "Running: pip install torch==${PYTORCH_VERSION} torchvision==${TORCHVISION_VERSION} torchaudio==${TORCHAUDIO_VERSION} --index-url https://download.pytorch.org/whl/rocm${ROCM_VERSION}"
    
    if ! pip install \
        "torch==${PYTORCH_VERSION}" \
        "torchvision==${TORCHVISION_VERSION}" \
        "torchaudio==${TORCHAUDIO_VERSION}" \
        --index-url "https://download.pytorch.org/whl/rocm${ROCM_VERSION}" \
        2>&1 | tee -a "$LOG_FILE"; then
        log_error "PyTorch installation failed"
        return 1
    fi
    
    log_success "PyTorch installation completed"
    
    return 0
}

# Verify PyTorch installation
verify_pytorch() {
    log_info "Verifying PyTorch installation..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Check installed packages
    log_info "Checking installed PyTorch packages:"
    pip list | grep -E "(torch|rocm)" | tee -a "$LOG_FILE"
    
    # Verify PyTorch can be imported
    log_info "Testing PyTorch import..."
    if ! python -c "import torch" 2>&1 | tee -a "$LOG_FILE"; then
        log_error "Failed to import PyTorch"
        return 1
    fi
    
    log_success "PyTorch import successful"
    
    # Check PyTorch version
    TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
    log "PyTorch version: $TORCH_VERSION"
    
    if [[ ! "$TORCH_VERSION" == "${PYTORCH_VERSION}+rocm"* ]]; then
        log_error "PyTorch version mismatch. Expected ${PYTORCH_VERSION}+rocm*, got $TORCH_VERSION"
        return 1
    fi
    
    log_success "PyTorch version is correct"
    
    return 0
}

# Test CUDA availability
test_cuda_availability() {
    log_info "Testing CUDA availability (ROCm compatibility)..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Test torch.cuda.is_available()
    log_info "Running: python -c 'import torch; print(torch.cuda.is_available())'"
    CUDA_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())")
    
    log "CUDA available: $CUDA_AVAILABLE"
    
    if [ "$CUDA_AVAILABLE" != "True" ]; then
        log_error "CUDA is not available!"
        log_error "This means PyTorch cannot detect the AMD GPU via ROCm"
        log_error ""
        log_error "Possible issues:"
        log_error "  1. HSA_OVERRIDE_GFX_VERSION not set correctly"
        log_error "  2. ROCm not properly installed"
        log_error "  3. System needs reboot after ROCm installation"
        log_error ""
        return 1
    fi
    
    log_success "CUDA is available (ROCm working)"
    
    return 0
}

# Test GPU detection
test_gpu_detection() {
    log_info "Testing GPU detection..."
    
    # Ensure conda environment is activated
    source "$(conda info --base)/etc/profile.d/conda.sh"
    conda activate "$CONDA_ENV_NAME"
    
    # Get device name
    log_info "Running: python -c \"import torch; print(f'device name [0]:', torch.cuda.get_device_name(0))\""
    DEVICE_NAME=$(python -c "import torch; print(f'device name [0]:', torch.cuda.get_device_name(0))" 2>&1)
    
    log "$DEVICE_NAME"
    
    if [[ "$DEVICE_NAME" == *"AMD Radeon Graphics"* ]]; then
        log_success "AMD Radeon Graphics detected successfully"
    else
        log_warning "Unexpected device name: $DEVICE_NAME"
        log_warning "Expected 'AMD Radeon Graphics'"
    fi
    
    return 0
}

# Create completion marker
create_marker() {
    log_info "Creating completion marker..."
    echo "PyTorch ${PYTORCH_VERSION} with ROCm ${ROCM_VERSION} installed on $(date)" > "$MARKER_FILE"
    log_success "Marker created: $MARKER_FILE"
}

# Print next steps
print_next_steps() {
    echo ""
    echo "=============================================="
    log_success "PyTorch Setup Complete!"
    echo "=============================================="
    echo ""
    log_info "To use PyTorch with ROCm in future sessions:"
    log_info "  1. conda activate $CONDA_ENV_NAME"
    log_info "  2. Your code will automatically use the AMD GPU"
    echo ""
    log_info "Next step: Run ./04_setup_lerobot.sh"
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
            log_info "No setup needed. Proceed to next step: ./04_setup_lerobot.sh"
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
    
    # Setup HSA_OVERRIDE_GFX_VERSION
    if ! setup_hsa_override; then
        log_error "Failed to setup HSA_OVERRIDE_GFX_VERSION"
        exit 1
    fi
    
    echo ""
    
    # Setup conda environment
    if ! setup_conda_env; then
        log_error "Failed to setup conda environment"
        exit 1
    fi
    
    echo ""
    
    # Install PyTorch
    if ! install_pytorch; then
        log_error "PyTorch installation failed"
        exit 1
    fi
    
    echo ""
    
    # Verify PyTorch
    if ! verify_pytorch; then
        log_error "PyTorch verification failed"
        exit 1
    fi
    
    echo ""
    
    # Test CUDA availability
    if ! test_cuda_availability; then
        log_error "CUDA availability test failed"
        log_error "You may need to reboot and try again"
        exit 1
    fi
    
    echo ""
    
    # Test GPU detection
    if ! test_gpu_detection; then
        log_warning "GPU detection had issues, but setup may still work"
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