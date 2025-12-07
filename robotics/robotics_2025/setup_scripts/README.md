# LeRobot Setup Scripts for AMD Ryzen AI PC

Automated setup scripts for installing and configuring LeRobot development environment on AMD Ryzen AI PC with ROCm support.

## 📋 Overview

These scripts automate the complete setup process described in [`QuickStart.md`](../QuickStart.md), including:

- ✅ System verification (Ubuntu 24.04, amdgpu driver)
- ✅ ROCm 6.3.x installation
- ✅ PyTorch 2.7.1 with ROCm 6.3 setup
- ✅ LeRobot v0.4.1 installation
- ✅ Feetech servo SDK for SO-ARM101

## 🚀 Quick Start

### Option 1: Automated Full Setup (Recommended)

Run the master setup script to automatically execute all steps:

```bash
cd robotics/robotics_2025/setup_scripts
chmod +x *.sh
./00_master_setup.sh
```

The script will:
1. Verify your system meets requirements
2. Install ROCm 6.3.x
3. Prompt for reboot (required after ROCm installation)
4. After reboot, re-run the script to continue with PyTorch and LeRobot setup

### Option 2: Step-by-Step Manual Setup

Run each script individually for more control:

```bash
cd robotics/robotics_2025/setup_scripts
chmod +x *.sh

# Step 1: Verify system prerequisites
./01_verify_system.sh

# Step 2: Install ROCm (requires reboot after)
./02_install_rocm.sh
sudo reboot

# After reboot, continue:

# Step 3: Setup PyTorch with ROCm
./03_setup_pytorch.sh

# Step 4: Setup LeRobot
./04_setup_lerobot.sh
```

## 📁 Script Descriptions

### [`00_master_setup.sh`](00_master_setup.sh)
**Master orchestration script** - Runs all setup steps in sequence with progress tracking and automatic resume capability.

**Features:**
- Automatic progress tracking with state markers
- Resume from last successful step after reboot
- Comprehensive error handling
- Beautiful progress display

**Usage:**
```bash
./00_master_setup.sh
```

---

### [`01_verify_system.sh`](01_verify_system.sh)
**System verification** - Checks if your system meets all prerequisites.

**Checks:**
- Ubuntu 24.04 LTS (noble)
- Kernel version (6.14+ recommended)
- amdgpu driver loaded
- User groups (render, video)
- VRAM allocation (informational)
- Disk space (20GB+ required)

**Exit Codes:**
- `0` - All checks passed
- `1` - One or more checks failed

**Usage:**
```bash
./01_verify_system.sh
```

---

### [`02_install_rocm.sh`](02_install_rocm.sh)
**ROCm installation** - Installs ROCm 6.3.x with safety checks.

**Features:**
- Downloads and installs amdgpu-install package
- Installs ROCm with `--no-dkms` flag (uses built-in kernel driver)
- Adds user to render and video groups
- Idempotent (safe to re-run)
- Prompts for required reboot

**Exit Codes:**
- `0` - Installation successful (reboot required)
- `1` - Installation failed
- `2` - Already installed

**Usage:**
```bash
./02_install_rocm.sh
```

**Important:** System reboot is required after ROCm installation!

---

### [`03_setup_pytorch.sh`](03_setup_pytorch.sh)
**PyTorch setup** - Creates conda environment and installs PyTorch 2.7.1 with ROCm 6.3.

**Features:**
- Creates `lerobot` conda environment with Python 3.10
- Sets `HSA_OVERRIDE_GFX_VERSION=11.0.0` for Ryzen AI 300 series
- Installs PyTorch 2.7.1, torchvision 0.22.1, torchaudio 2.7.1
- Verifies GPU detection via ROCm
- Tests CUDA availability

**Prerequisites:**
- ROCm must be installed
- Miniconda/Anaconda must be installed

**Exit Codes:**
- `0` - Setup successful
- `1` - Setup failed
- `2` - Already configured

**Usage:**
```bash
./03_setup_pytorch.sh
```

---

### [`04_setup_lerobot.sh`](04_setup_lerobot.sh)
**LeRobot setup** - Clones and installs LeRobot v0.4.1 development environment.

**Features:**
- Installs ffmpeg 7.1.1 via conda-forge
- Clones LeRobot repository to `~/lerobot`
- Checks out v0.4.1 tag
- Installs LeRobot in editable mode
- Installs feetech servo SDK for SO-ARM101
- Verifies installation

**Prerequisites:**
- PyTorch must be installed in `lerobot` conda environment

**Exit Codes:**
- `0` - Setup successful
- `1` - Setup failed
- `2` - Already configured

**Usage:**
```bash
./04_setup_lerobot.sh
```

---

## 📊 Logging

All scripts create detailed log files in the `logs/` directory:

```
logs/
├── 00_master_setup_YYYYMMDD_HHMMSS.log
├── 01_verify_system_YYYYMMDD_HHMMSS.log
├── 02_install_rocm_YYYYMMDD_HHMMSS.log
├── 03_setup_pytorch_YYYYMMDD_HHMMSS.log
├── 04_setup_lerobot_YYYYMMDD_HHMMSS.log
├── .step_01_complete  # State markers
├── .step_02_complete
├── .step_03_complete
├── .step_04_complete
└── .master_setup_complete
```

**Log Features:**
- Timestamped entries
- Color-coded console output
- Complete command output
- Error messages and diagnostics

## 🔄 Idempotency

All scripts are **idempotent** - safe to run multiple times:

- ✅ Skip already completed steps
- ✅ Detect existing installations
- ✅ Resume after failures
- ✅ State tracking with marker files

## 🛠️ Troubleshooting

### Script Not Executable
```bash
chmod +x *.sh
```

### Resume After Failure
Simply re-run the failed script or the master script:
```bash
./00_master_setup.sh  # Automatically resumes from last successful step
```

### Reset Everything
To start fresh, remove all marker files:
```bash
rm logs/.step_*
rm logs/.master_setup_complete
```

### Check Logs
View the most recent log for a specific step:
```bash
ls -lt logs/01_verify_system_*.log | head -1 | xargs cat
```

### Common Issues

**Issue:** "amdgpu driver is not loaded"
- **Solution:** Ensure you have an AMD Ryzen AI PC with integrated graphics
- Check BIOS settings for GPU configuration

**Issue:** "Conda is not installed"
- **Solution:** Install Miniconda:
  ```bash
  mkdir -p ~/miniconda3
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda3/miniconda.sh
  bash ~/miniconda3/miniconda.sh -b -u -p ~/miniconda3
  rm ~/miniconda3/miniconda.sh
  ~/miniconda3/bin/conda init bash
  source ~/.bashrc
  ```

**Issue:** "CUDA is not available" after PyTorch installation
- **Solution:** Reboot the system if you haven't already after ROCm installation
- Verify `HSA_OVERRIDE_GFX_VERSION` is set: `echo $HSA_OVERRIDE_GFX_VERSION`

**Issue:** ROCm installation fails
- **Solution:** Check internet connectivity
- Ensure you have sufficient disk space (20GB+)
- Review the log file for specific errors

## 📚 Next Steps

After successful setup:

1. **Activate the environment:**
   ```bash
   conda activate lerobot
   ```

2. **Navigate to LeRobot directory:**
   ```bash
   cd ~/lerobot
   ```

3. **Follow LeRobot documentation:**
   - Calibration
   - Teleoperation
   - Creating datasets
   - Inference evaluation with SO-101 ARM

4. **For training setup:**
   - See [`training-models-on-rocm.ipynb`](../training-models-on-rocm.ipynb)

## 📖 Documentation

- **LeRobot Documentation:** https://huggingface.co/docs/lerobot/index
- **QuickStart Guide:** [`../QuickStart.md`](../QuickStart.md)
- **ROCm Documentation:** https://rocm.docs.amd.com/
- **Setup Plan:** [`PLAN.md`](PLAN.md) (detailed architecture)

## 🎯 System Requirements

- **Hardware:** AMD Ryzen AI 9 HX370 PC (or compatible)
- **OS:** Ubuntu 24.04 LTS (noble)
- **VRAM:** 16GB+ (set in BIOS)
- **Disk Space:** 20GB+ free
- **Internet:** Required for downloads

## 🔐 Permissions

Scripts require:
- Regular user permissions for most operations
- `sudo` access for:
  - Installing system packages
  - Installing ROCm
  - Adding user to groups
  - Rebooting system

## ⚠️ Important Notes

1. **Reboot Required:** After ROCm installation, a system reboot is mandatory
2. **Group Changes:** After being added to render/video groups, logout/login or reboot is required
3. **Conda Environment:** Always activate `lerobot` environment before using LeRobot
4. **HSA Override:** The `HSA_OVERRIDE_GFX_VERSION=11.0.0` setting is added to `~/.bashrc`
5. **Installation Location:** LeRobot is installed at `~/lerobot` by default

## 🤝 Support

If you encounter issues:

1. Check the log files in `logs/` directory
2. Review the troubleshooting section above
3. Consult the QuickStart.md documentation
4. Check the PLAN.md for detailed architecture information

## 📝 License

These scripts are part of the AMD Hackathon robotics project and follow the same license as the parent project.

---

**Happy Hacking! 🚀🤖**