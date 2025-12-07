# Arm Camera Flickering Fix - Quick Guide

## Problem
The arm camera shows flickering, horizontal lines, or unstable video in rerun viewer.

## Root Cause
USB bandwidth contention when multiple cameras compete for bandwidth, especially when using uncompressed video formats.

## Quick Fix (Recommended)

### Step 1: Run the Configuration Script
```bash
cd robotics/robotics_2025/so101_scripts
./utils/configure_arm_camera.sh
```

This automatically:
- Sets MJPEG format (70% bandwidth reduction)
- Lowers frame rate to 10 FPS
- Disables auto-exposure and auto-white-balance
- Optimizes buffer settings

### Step 2: Update Your .env File
```bash
# Add these lines to your .env file:
ARM_CAMERA_FPS=10
ARM_CAMERA_FORMAT=MJPG
ARM_CAMERA_BUFFER_SIZE=4
```

### Step 3: Test
```bash
# Test the camera
ffplay /dev/video4

# Or run teleoperation
./scripts/06_teleoperate_with_cameras.sh
```

## What Changed

### Before (Problematic)
- **Format:** YUYV (uncompressed)
- **Bandwidth:** ~280 Mbps @ 30 FPS
- **Frame Rate:** 30 FPS (same as other cameras)
- **Auto Settings:** Enabled (causes flickering)

### After (Optimized)
- **Format:** MJPEG (compressed)
- **Bandwidth:** ~27 Mbps @ 10 FPS (90% reduction!)
- **Frame Rate:** 10 FPS (sufficient for training)
- **Auto Settings:** Disabled (stable exposure/white balance)

## Key Settings Explained

### ARM_CAMERA_FPS=10
- **Why:** Reduces USB bandwidth by 67% compared to 30 FPS
- **Impact:** Still smooth enough for robot training
- **Alternatives:** Try 8 or 5 FPS if still flickering

### ARM_CAMERA_FORMAT=MJPG
- **Why:** MJPEG compression reduces bandwidth by ~70%
- **Impact:** Much less USB traffic, more stable
- **Note:** Most USB cameras support MJPEG

### Fixed Exposure/White Balance
- **Why:** Auto-adjustments cause frame-to-frame variations
- **Impact:** Consistent image quality, no flickering
- **Values:** Optimized for typical indoor lighting

## USB Topology Best Practices

### Ideal Setup
```
USB Controller 1 → Top Camera (640x480 @ 30 FPS)
USB Controller 2 → Side Camera (640x480 @ 30 FPS)
USB Controller 3 → Arm Camera (640x480 @ 10 FPS, MJPEG)
```

### Check Your Setup
```bash
# View USB topology
lsusb -t

# Look for cameras on different buses
# Bus 01, Bus 02, Bus 03 = different controllers ✓
# All on Bus 01 = shared bandwidth ✗
```

### Tips
- Connect arm camera to a **different USB port** than other cameras
- Avoid USB hubs if possible
- Use USB 3.0 ports for best performance
- Use high-quality USB cables

## Troubleshooting

### Still Flickering?

1. **Lower FPS further:**
   ```bash
   # In .env
   ARM_CAMERA_FPS=5
   ```

2. **Reduce resolution:**
   ```bash
   # In .env
   ARM_CAMERA_WIDTH=320
   ARM_CAMERA_HEIGHT=240
   ```

3. **Check USB topology:**
   ```bash
   lsusb -t
   # Move camera to different USB controller
   ```

4. **Verify MJPEG is active:**
   ```bash
   v4l2-ctl -d /dev/video4 --get-fmt-video
   # Should show: Pixel Format: 'MJPG'
   ```

### Manual Configuration

If the script doesn't work:
```bash
# Set MJPEG format
v4l2-ctl -d /dev/video4 --set-fmt-video=width=640,height=480,pixelformat=MJPG

# Set frame rate
v4l2-ctl -d /dev/video4 --set-parm=10

# Disable auto-exposure
v4l2-ctl -d /dev/video4 --set-ctrl=exposure_auto=1
v4l2-ctl -d /dev/video4 --set-ctrl=exposure_absolute=156

# Disable auto white balance
v4l2-ctl -d /dev/video4 --set-ctrl=white_balance_temperature_auto=0
v4l2-ctl -d /dev/video4 --set-ctrl=white_balance_temperature=4600
```

## Verification

### Check Settings
```bash
v4l2-ctl -d /dev/video4 --all | grep -E "(Format|Frames|Exposure|White)"
```

### Expected Output
```
Pixel Format      : 'MJPG' (Motion-JPEG)
Width/Height      : 640/480
Frames per Second : 10.000
Exposure, Auto    : Manual Mode
White Balance Temp: Manual Mode
```

### Test Video Quality
```bash
# Quick test with ffplay
ffplay /dev/video4

# Should see:
# - Smooth video (no flickering)
# - No horizontal lines
# - Consistent brightness/color
```

## Integration

The fix is automatically applied when you run:
- [`./scripts/06_teleoperate_with_cameras.sh`](scripts/06_teleoperate_with_cameras.sh)
- [`./scripts/07_record_dataset.sh`](scripts/07_record_dataset.sh)

Both scripts now call [`configure_arm_camera.sh`](utils/configure_arm_camera.sh) before starting.

## Performance Impact

### Bandwidth Comparison
| Configuration | Bandwidth | USB Load |
|--------------|-----------|----------|
| YUYV @ 30 FPS | 280 Mbps | 58% of USB 2.0 |
| MJPEG @ 30 FPS | 80 Mbps | 17% of USB 2.0 |
| MJPEG @ 10 FPS | 27 Mbps | 6% of USB 2.0 ✓ |

### Training Impact
- **10 FPS is sufficient** for robot learning
- Models train on frame sequences, not real-time video
- Lower FPS = more stable data = better training

## Additional Resources

- Full troubleshooting: [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)
- Camera configuration: [`config/camera_config.sh`](config/camera_config.sh)
- Configuration script: [`utils/configure_arm_camera.sh`](utils/configure_arm_camera.sh)

## Summary

**The fix reduces arm camera bandwidth by 90% while maintaining quality for training.**

Key changes:
1. ✓ MJPEG compression (70% bandwidth reduction)
2. ✓ Lower frame rate (67% bandwidth reduction)
3. ✓ Fixed exposure/white balance (eliminates flickering)
4. ✓ Automatic configuration in scripts

**Result:** Stable, flicker-free arm camera feed in rerun! 🎉