#!/bin/bash
################################################################################
# Script: configure_arm_camera.sh
# Purpose: Configure arm camera to reduce flickering and improve stability
# Usage: ./utils/configure_arm_camera.sh
################################################################################

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

# Load camera configuration
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi
source "$SCRIPT_DIR/config/camera_config.sh"

echo ""
echo "=============================================="
echo "  Configure Arm Camera for Stability"
echo "=============================================="
echo ""

# Check if v4l2-ctl is available
if ! command -v v4l2-ctl &> /dev/null; then
    log_error "v4l2-ctl not found"
    log_info "Installing v4l-utils..."
    sudo apt update && sudo apt install -y v4l-utils
fi

log_success "v4l2-ctl is available"
echo ""

# Check if arm camera exists
if [ ! -e "$ARM_CAMERA_DEVICE" ]; then
    log_error "Arm camera not found: $ARM_CAMERA_DEVICE"
    exit 1
fi

log_info "Configuring arm camera: $ARM_CAMERA_DEVICE"
echo ""

# Display current settings
log_info "Current camera settings:"
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --all 2>&1 | grep -E "(Width|Height|Pixel Format|Frames per second|Brightness|Contrast|Saturation|Exposure)" || true
echo ""

# Apply optimized settings for stability
log_info "Applying optimized settings..."

# 1. Set pixel format to MJPEG (reduces USB bandwidth)
log_info "Setting pixel format to MJPEG..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-fmt-video=width=${CAMERA_WIDTH},height=${CAMERA_HEIGHT},pixelformat=MJPG 2>&1 || {
    log_warning "MJPEG not supported, trying YUYV..."
    v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-fmt-video=width=${CAMERA_WIDTH},height=${CAMERA_HEIGHT},pixelformat=YUYV 2>&1 || true
}

# 2. Set frame rate
log_info "Setting frame rate to ${ARM_CAMERA_FPS} fps..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-parm=${ARM_CAMERA_FPS} 2>&1 || true

# 3. Disable auto-exposure (reduces flickering)
log_info "Configuring exposure settings..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=exposure_auto=1 2>&1 || true  # 1 = manual mode
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=exposure_absolute=156 2>&1 || true  # Fixed exposure

# 4. Disable auto white balance (reduces color shifts)
log_info "Configuring white balance..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=white_balance_temperature_auto=0 2>&1 || true
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=white_balance_temperature=4600 2>&1 || true

# 5. Set fixed gain (reduces noise)
log_info "Configuring gain..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=gain_automatic=0 2>&1 || true
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=gain=100 2>&1 || true

# 6. Disable power line frequency compensation (reduces banding)
log_info "Disabling power line frequency compensation..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=power_line_frequency=0 2>&1 || true

# 7. Set brightness, contrast, saturation to neutral
log_info "Setting image quality parameters..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=brightness=128 2>&1 || true
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=contrast=128 2>&1 || true
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=saturation=128 2>&1 || true
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=sharpness=128 2>&1 || true

# 8. Disable backlight compensation
log_info "Disabling backlight compensation..."
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --set-ctrl=backlight_compensation=0 2>&1 || true

echo ""
log_success "Camera configuration complete!"
echo ""

# Display new settings
log_info "New camera settings:"
v4l2-ctl -d "$ARM_CAMERA_DEVICE" --all 2>&1 | grep -E "(Width|Height|Pixel Format|Frames per second|Brightness|Contrast|Saturation|Exposure)" || true
echo ""

log_info "Tips for best results:"
echo "  1. Run this script before starting teleoperation or recording"
echo "  2. If flickering persists, try lowering ARM_CAMERA_FPS in .env"
echo "  3. Ensure arm camera is on a separate USB controller from other cameras"
echo "  4. Use 'lsusb -t' to check USB bus topology"
echo ""

exit 0