# SO101 ARM Troubleshooting Guide

## Issue: Robot Arms Not Detected (No /dev/ttyACM* devices)

### Symptoms
- Red lights on robot arms (power is working)
- Arms connected via USB
- No `/dev/ttyACM*` or `/dev/ttyUSB*` devices appear
- `lsusb` doesn't show the robot arms

### Root Cause
The USB-to-serial drivers (cdc_acm) are not loaded in the kernel.

### Solutions

#### Solution 1: Load the cdc_acm Driver (Quick Fix)

```bash
# Load the USB ACM driver
sudo modprobe cdc_acm

# Verify it's loaded
lsmod | grep cdc_acm

# Now unplug and replug the robot arms
# Check if devices appear
ls /dev/ttyACM*
```

#### Solution 2: Install USB Serial Drivers

If modprobe doesn't work, you may need to install the drivers:

```bash
# Install USB serial support
sudo apt update
sudo apt install linux-modules-extra-$(uname -r)

# Reboot
sudo reboot

# After reboot, check again
ls /dev/ttyACM*
```

#### Solution 3: Try Different USB Ports

The issue might be with the USB hubs:

1. **Try direct connection**: Connect arms directly to laptop USB ports (not through hubs)
2. **Try different ports**: Some USB ports may have better compatibility
3. **One at a time**: Connect one arm first, verify it appears, then connect the second

#### Solution 4: Check USB Cable Quality

- SO101 arms need **data-capable USB cables** (not just power cables)
- Try different USB-C cables if available
- Ensure cables are fully inserted

### Verification Steps

After trying solutions, verify the connection:

```bash
# 1. Check if devices appear
ls -la /dev/ttyACM*

# 2. Check USB devices
lsusb | grep -i "serial\|acm\|uart"

# 3. Run our verification script
cd robotics/robotics_2025/so101_scripts
./scripts/00_verify_setup.sh

# 4. Use LeRobot's port finder
conda activate lerobot
lerobot-find-port
```

### Expected Output

When working correctly, you should see:

```bash
$ ls /dev/ttyACM*
/dev/ttyACM0  /dev/ttyACM1
```

- `/dev/ttyACM0` - First arm connected (usually leader)
- `/dev/ttyACM1` - Second arm connected (usually follower)

### Connection Order Matters

The device names depend on connection order:

1. **Connect LEADER first** → gets `/dev/ttyACM0`
2. **Connect FOLLOWER second** → gets `/dev/ttyACM1`

If you connect in different order, update your `.env` file:

```bash
# Edit .env
nano .env

# Update these lines:
LEADER_PORT=/dev/ttyACM0    # or /dev/ttyACM1
FOLLOWER_PORT=/dev/ttyACM1  # or /dev/ttyACM0
```

### Still Not Working?

#### Check Kernel Messages (requires sudo)

```bash
# Watch for USB events in real-time
sudo dmesg -w

# In another terminal, unplug and replug an arm
# Look for messages about USB devices
```

#### Check if Arms are in Bootloader Mode

Some SO101 arms have a button that puts them in bootloader mode:
- Make sure the arm is in **normal mode**, not bootloader mode
- Try pressing any buttons on the control board

#### Verify Arm Power

- Red LED should be solid (not blinking)
- Try different power sources if using external power
- Some arms need both USB data AND external power

### Hardware Checklist

- [ ] Arms have red LED lights on
- [ ] Using data-capable USB cables (not charge-only)
- [ ] Cables fully inserted on both ends
- [ ] Tried direct connection (no hubs)
- [ ] Tried different USB ports
- [ ] cdc_acm driver loaded (`lsmod | grep cdc_acm`)
- [ ] Connected arms one at a time to test

### Quick Diagnostic Script

Run this to get full diagnostic info:

```bash
#!/bin/bash
echo "=== USB Devices ==="
lsusb

echo -e "\n=== Serial Devices ==="
ls -la /dev/tty{ACM,USB}* 2>&1

echo -e "\n=== Loaded Drivers ==="
lsmod | grep -E "(cdc_acm|ch341|cp210x|ftdi)"

echo -e "\n=== Kernel Version ==="
uname -r

echo -e "\n=== USB Modules ==="
ls /lib/modules/$(uname -r)/kernel/drivers/usb/serial/ 2>&1
```

Save as `diagnose.sh`, make executable, and run:

```bash
chmod +x diagnose.sh
./diagnose.sh
```

### Common Error Messages

**"No such file or directory" for /dev/ttyACM***
- Driver not loaded or arms not detected
- Try Solution 1 or 2 above

**"Permission denied" when accessing /dev/ttyACM***
- Run: `./scripts/01_set_permissions.sh`
- Or manually: `sudo chmod 666 /dev/ttyACM*`

**Arms detected but calibration fails**
- Wrong port assignment (leader/follower swapped)
- Check connection order
- Update `.env` file

### Getting Help

If still having issues:

1. Run the diagnostic script above
2. Check the logs in `logs/` directory
3. Review LeRobot documentation: https://huggingface.co/docs/lerobot/so101
4. Check SO101 hardware documentation

### Next Steps After Fix

Once arms are detected:

```bash
cd robotics/robotics_2025/so101_scripts

# 1. Verify setup
./scripts/00_verify_setup.sh

# 2. Set permissions
./scripts/01_set_permissions.sh

# 3. Calibrate
./scripts/02_calibrate_follower.sh
./scripts/03_calibrate_leader.sh
```

---

## Issue: Arm Camera Flickering, Lines, or Poor Quality in Rerun

### Symptoms
- Flickering or unstable arm camera feed in rerun viewer
- Horizontal lines across the image
- Image appears to be mixing frames or tearing
- Choppy or stuttering video
- Color shifts or exposure changes

### Root Causes
1. **USB Bandwidth Contention** - Multiple cameras competing for USB bandwidth
2. **Buffer Underruns** - Camera not getting frames fast enough
3. **Incorrect Pixel Format** - Using uncompressed format (YUYV) instead of MJPEG
4. **Auto-Exposure/White Balance** - Automatic adjustments causing flickering
5. **USB Hub Issues** - Poor quality or overloaded USB hubs
6. **Frame Rate Too High** - Arm camera trying to match other cameras' FPS

### Solutions

#### Solution 1: Run the Camera Configuration Script (Recommended)

The easiest fix is to run our automated configuration script:

```bash
cd robotics/robotics_2025/so101_scripts

# Configure arm camera with optimized settings
./utils/configure_arm_camera.sh
```

This script will:
- Set pixel format to MJPEG (reduces bandwidth by ~70%)
- Lower frame rate to 10 FPS (reduces USB load)
- Disable auto-exposure and auto-white-balance (reduces flickering)
- Set fixed gain and exposure values
- Optimize buffer settings

The configuration is automatically applied when you run:
- `./scripts/06_teleoperate_with_cameras.sh`
- `./scripts/07_record_dataset.sh`

#### Solution 2: Adjust Frame Rate in .env

Lower the arm camera frame rate to reduce bandwidth:

```bash
# Edit .env file
nano .env

# Add or modify this line:
ARM_CAMERA_FPS=10    # Try 10, 8, or even 5 FPS

# Save and restart your recording/teleoperation
```

Lower FPS options:
- **15 FPS** - Default, good for most cases
- **10 FPS** - Better stability, still smooth enough
- **8 FPS** - Very stable, acceptable for training
- **5 FPS** - Maximum stability, minimum bandwidth

#### Solution 3: Separate USB Controllers

Ensure cameras are on different USB controllers to avoid bandwidth sharing:

```bash
# Check USB topology
lsusb -t

# Look for cameras on different USB buses
# Example output:
/:  Bus 01.Port 1: Dev 1, Class=root_hub
    |__ Port 1: Dev 2, If 0, Class=Video  # Top camera
/:  Bus 02.Port 1: Dev 1, Class=root_hub
    |__ Port 1: Dev 3, If 0, Class=Video  # Side camera
/:  Bus 03.Port 1: Dev 1, Class=root_hub
    |__ Port 1: Dev 4, If 0, Class=Video  # Arm camera (separate bus!)
```

**Best Practice:**
- Connect arm camera to a **different USB port** than other cameras
- Avoid USB hubs if possible - use direct laptop ports
- If using hubs, use separate hubs for different cameras

#### Solution 4: Manual v4l2 Configuration

If the script doesn't work, manually configure the camera:

```bash
# Set MJPEG format (most important!)
v4l2-ctl -d /dev/video4 --set-fmt-video=width=640,height=480,pixelformat=MJPG

# Set frame rate
v4l2-ctl -d /dev/video4 --set-parm=10

# Disable auto-exposure (reduces flickering)
v4l2-ctl -d /dev/video4 --set-ctrl=exposure_auto=1
v4l2-ctl -d /dev/video4 --set-ctrl=exposure_absolute=156

# Disable auto white balance
v4l2-ctl -d /dev/video4 --set-ctrl=white_balance_temperature_auto=0
v4l2-ctl -d /dev/video4 --set-ctrl=white_balance_temperature=4600

# Check current settings
v4l2-ctl -d /dev/video4 --all
```

#### Solution 5: Reduce Resolution

If bandwidth is still an issue, reduce the arm camera resolution:

```bash
# Edit .env
nano .env

# Add these lines:
ARM_CAMERA_WIDTH=320
ARM_CAMERA_HEIGHT=240

# Update camera_config.sh to use these values
```

Then modify [`camera_config.sh`](config/camera_config.sh) to use separate resolution for arm camera.

#### Solution 6: Check USB Cable Quality

- Use **high-quality USB cables** (USB 3.0 rated)
- Avoid long cables (>2 meters can cause issues)
- Try different cables if available
- Ensure cables are fully inserted

### Verification Steps

After applying fixes, verify the camera:

```bash
# 1. Check camera settings
v4l2-ctl -d /dev/video4 --all | grep -E "(Format|Frames|Exposure|White)"

# 2. Test with ffplay
ffplay /dev/video4

# 3. Run teleoperation test
./scripts/06_teleoperate_with_cameras.sh
```

### Expected Results

When properly configured, you should see:
- **Pixel Format:** MJPEG (not YUYV)
- **Frame Rate:** 10 FPS or lower
- **Exposure:** Manual mode with fixed value
- **White Balance:** Manual mode with fixed value
- **Smooth video** in rerun viewer without flickering or lines

### Advanced Diagnostics

#### Check USB Bandwidth Usage

```bash
# Install usbutils if needed
sudo apt install usbutils

# Monitor USB bandwidth
watch -n 1 'lsusb -t'

# Check for USB errors
dmesg | grep -i usb | tail -20
```

#### Test Camera Formats

```bash
# List supported formats
v4l2-ctl -d /dev/video4 --list-formats-ext

# Try different formats
v4l2-ctl -d /dev/video4 --set-fmt-video=pixelformat=MJPG
v4l2-ctl -d /dev/video4 --set-fmt-video=pixelformat=YUYV
```

#### Monitor Frame Drops

```bash
# Run with verbose logging
lerobot-record --robot.cameras=... --verbose 2>&1 | grep -i "drop\|skip\|late"
```

### USB Controller Recommendations

**Ideal Setup:**
- **USB Controller 1:** Top camera (640x480 @ 30 FPS)
- **USB Controller 2:** Side camera (640x480 @ 30 FPS)
- **USB Controller 3:** Arm camera (640x480 @ 10 FPS, MJPEG)

**Bandwidth Calculation:**
- YUYV 640x480 @ 30 FPS ≈ 280 Mbps
- MJPEG 640x480 @ 30 FPS ≈ 80 Mbps (70% reduction!)
- MJPEG 640x480 @ 10 FPS ≈ 27 Mbps (90% reduction!)

USB 2.0 bandwidth: 480 Mbps (theoretical), ~280 Mbps (practical)

### Quick Fix Checklist

- [ ] Run `./utils/configure_arm_camera.sh`
- [ ] Set `ARM_CAMERA_FPS=10` in `.env`
- [ ] Verify MJPEG format: `v4l2-ctl -d /dev/video4 --get-fmt-video`
- [ ] Connect arm camera to separate USB port/controller
- [ ] Use high-quality USB cable
- [ ] Disable auto-exposure and auto-white-balance
- [ ] Test with `ffplay /dev/video4` before recording

### Still Having Issues?

If flickering persists after trying all solutions:

1. **Try even lower FPS:** Set `ARM_CAMERA_FPS=5`
2. **Reduce resolution:** Use 320x240 instead of 640x480
3. **Check camera hardware:** Some cameras have hardware issues
4. **Update camera firmware:** Check manufacturer's website
5. **Try different camera:** Some USB cameras work better than others

### Common Error Messages

**"Cannot set format: Device or resource busy"**
- Camera is in use by another application
- Close all camera applications and try again
- Run: `fuser /dev/video4` to find processes using camera

**"VIDIOC_S_FMT: Invalid argument"**
- Camera doesn't support requested format
- Check supported formats: `v4l2-ctl -d /dev/video4 --list-formats-ext`
- Try YUYV if MJPEG not supported (but expect higher bandwidth)

**"Frame drops detected"**
- USB bandwidth exceeded
- Lower FPS or resolution
- Move camera to different USB controller

---

**Last Updated:** 2025-12-07