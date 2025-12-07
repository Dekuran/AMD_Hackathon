#!/bin/bash
################################################################################
# Script: 11_prepare_datasets_for_cloud_training.sh
# Purpose:
#   - Ensure meta/info.json exists for local 11ep and 30ep datasets
#   - Re-upload both datasets to Hugging Face via existing 08_* scripts
#   - Build the combined 41ep HF dataset via 10_combine_trash_datasets.sh
#
# After this script finishes successfully, you can go to your CLOUD Jupyter
# notebook and run SmolVLA training on:
#   - HF_USER/trash_sorting_11ep
#   - HF_USER/trash_sorting_30ep
#   - HF_USER/trash_sorting_41ep_combo (combined)
#
# Usage:
#   cd robotics/robotics_2025/so101_scripts
#   chmod +x scripts/11_prepare_datasets_for_cloud_training.sh
#   ./scripts/11_prepare_datasets_for_cloud_training.sh
################################################################################

set -euo pipefail

# Script root = .../so101_scripts
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Color codes (same style as other scripts)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "============================================================"
echo "  Prepare Datasets for SmolVLA Cloud Training"
echo "  - Patch meta/info.json (codebase_version)"
echo "  - Re-upload 11ep + 30ep datasets"
echo "  - Build 41ep combined dataset on HF"
echo "============================================================"
echo ""

################################################################################
# Step 0: Load .env and basic checks (HF_USER / HF_TOKEN)
################################################################################
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo -e "${RED}[ERROR]${NC} Missing .env at $SCRIPT_DIR/.env"
    echo "  Create it from .env.trash_sorting:"
    echo "    cd $SCRIPT_DIR"
    echo "    cp .env.trash_sorting .env"
    echo "    # then edit .env to set HF_USER, HF_TOKEN, etc."
    exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT_DIR/.env"
echo -e "${GREEN}[OK]${NC} Loaded configuration from $SCRIPT_DIR/.env"
echo ""

if [ -z "${HF_USER:-}" ] || [ "$HF_USER" = "your_huggingface_username" ]; then
    echo -e "${RED}[ERROR]${NC} HF_USER is not set correctly in .env"
    echo "  Edit $SCRIPT_DIR/.env and set HF_USER to your HF username (e.g. DekuranC)"
    exit 1
fi

if [ -z "${HF_TOKEN:-}" ] || [ "$HF_TOKEN" = "your_huggingface_token_here" ]; then
    echo -e "${RED}[ERROR]${NC} HF_TOKEN is not set correctly in .env"
    echo "  Edit $SCRIPT_DIR/.env and set HF_TOKEN to your real HF token"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} HuggingFace user : ${HF_USER}"
echo ""

################################################################################
# Step 1: Activate conda env (same as other SO101 scripts)
################################################################################
if [ -f "$SCRIPT_DIR/utils/activate_env.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/utils/activate_env.sh"
    echo -e "${GREEN}[OK]${NC} Conda environment activated"
else
    echo -e "${YELLOW}[WARN]${NC} activate_env.sh not found at $SCRIPT_DIR/utils/activate_env.sh"
    echo "  Assuming you're already in the correct Python environment."
fi
echo ""

################################################################################
# Step 2: Ensure meta/info.json for 11ep and 30ep local datasets
################################################################################
echo -e "${BLUE}[INFO]${NC} Ensuring meta/info.json exists for local datasets..."

# Local dataset paths from the v5/v8 upload scripts
DATASET_11_PATH="${HOME}/so101_datasets/trash_sorting_40ep_v5"
DATASET_30_PATH="${HOME}/so101_datasets/trash_sorting_40ep_v8"

export DATASET_11_PATH DATASET_30_PATH

python - << 'PYCODE'
import json
import os
from pathlib import Path

def ensure_meta(path: Path, total_episodes: int):
    if not path.exists():
        print(f"[Python][WARN] Dataset path does not exist, skipping meta patch: {path}")
        return

    meta_dir = path / "meta"
    info_path = meta_dir / "info.json"
    meta_dir.mkdir(parents=True, exist_ok=True)

    # Load existing info if present
    info = {}
    if info_path.exists():
        try:
            info = json.loads(info_path.read_text())
            print(f"[Python][INFO] Loaded existing info.json from {info_path}")
        except Exception as e:
            print(f"[Python][WARN] Could not parse existing info.json at {info_path}: {e}")
            info = {}

    # Try to get installed lerobot version
    try:
        import lerobot
        codebase_version = f"lerobot_{lerobot.__version__}"
    except Exception:
        codebase_version = "lerobot_unknown"

    # Ensure required fields
    if "codebase_version" not in info:
        info["codebase_version"] = codebase_version
    if "total_episodes" not in info:
        info["total_episodes"] = total_episodes

    info_path.write_text(json.dumps(info, indent=2))
    print(f"[Python][OK] Wrote info.json at {info_path} with codebase_version={info['codebase_version']} total_episodes={info['total_episodes']}")

dataset_11_path = Path(os.path.expanduser(os.getenv("DATASET_11_PATH", "")))
dataset_30_path = Path(os.path.expanduser(os.getenv("DATASET_30_PATH", "")))

ensure_meta(dataset_11_path, total_episodes=11)
ensure_meta(dataset_30_path, total_episodes=30)
PYCODE

echo ""

################################################################################
# Step 3: Login to Hugging Face (if not already)
################################################################################
echo -e "${BLUE}[INFO]${NC} Verifying HuggingFace CLI login..."
if ! huggingface-cli whoami >/dev/null 2>&1; then
    echo -e "${YELLOW}[WARN]${NC} Not logged in with huggingface-cli, running utils/hf_login.sh..."
    if [ -x "$SCRIPT_DIR/utils/hf_login.sh" ]; then
        "$SCRIPT_DIR/utils/hf_login.sh"
    else
        echo -e "${RED}[ERROR]${NC} hf_login.sh not found or not executable at $SCRIPT_DIR/utils/hf_login.sh"
        exit 1
    fi
else
    echo -e "${GREEN}[OK]${NC} Already logged in to HuggingFace CLI"
fi
echo ""

################################################################################
# Step 4: Re-upload 11ep and 30ep datasets using existing scripts
################################################################################
echo -e "${BLUE}[INFO]${NC} Re-uploading 11-episode dataset via scripts/08_upload_dataset_v5.sh..."
if [ -x "$SCRIPT_DIR/scripts/08_upload_dataset_v5.sh" ]; then
    "$SCRIPT_DIR/scripts/08_upload_dataset_v5.sh"
else
    echo -e "${RED}[ERROR]${NC} scripts/08_upload_dataset_v5.sh not found or not executable"
    exit 1
fi
echo ""

echo -e "${BLUE}[INFO]${NC} Re-uploading 30-episode dataset via scripts/08_upload_dataset_v8.sh..."
if [ -x "$SCRIPT_DIR/scripts/08_upload_dataset_v8.sh" ]; then
    "$SCRIPT_DIR/scripts/08_upload_dataset_v8.sh"
else
    echo -e "${RED}[ERROR]${NC} scripts/08_upload_dataset_v8.sh not found or not executable"
    exit 1
fi
echo ""

################################################################################
# Step 5: Build 41-episode combined dataset on Hugging Face
################################################################################
echo -e "${BLUE}[INFO]${NC} Creating 41-episode combined dataset on Hugging Face..."
if [ -x "$SCRIPT_DIR/scripts/10_combine_trash_datasets.sh" ]; then
    "$SCRIPT_DIR/scripts/10_combine_trash_datasets.sh"
else
    echo -e "${RED}[ERROR]${NC} scripts/10_combine_trash_datasets.sh not found or not executable"
    exit 1
fi
echo ""

################################################################################
# Done – next steps on CLOUD Jupyter
################################################################################
echo "============================================================"
echo -e "${GREEN}[SUCCESS]${NC} Local datasets are patched, uploaded, and combined."
echo ""
echo "Next steps (on your CLOUD training machine / Jupyter):"
echo "  1) Open the notebook based on training_vla_experiments_notebook.md"
echo "  2) In Cell 2 (BASE_DATASETS), ensure you have entries for:"
echo "       - trash_11ep_naotoF  -> ${HF_USER}/trash_sorting_11ep"
echo "       - trash_30ep_main    -> ${HF_USER}/trash_sorting_30ep"
echo "       - trash_41ep_combo   -> ${HF_USER}/trash_sorting_41ep_combo"
echo "  3) Run Cell 3 to verify datasets load with LeRobot"
echo "  4) Use train_smolvla_on_dataset(...) calls in Cell 6 to launch training."
echo "============================================================"
echo ""