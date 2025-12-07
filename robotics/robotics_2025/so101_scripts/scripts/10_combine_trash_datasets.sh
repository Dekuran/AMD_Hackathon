#!/bin/bash
################################################################################
# Script: 10_combine_trash_datasets.sh
# Purpose: Combine two HF datasets (11ep + 30ep) into a 41ep combo dataset
# Usage:   ./scripts/10_combine_trash_datasets.sh
#
# This follows the SO101 scripts pattern:
#   - Reads HF_USER / HF_TOKEN from so101_scripts/.env
#   - Activates the same conda env via utils/activate_env.sh
#   - Uses Python (datasets + huggingface_hub) to combine + push
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
echo "=============================================="
echo "  Combine Trash Datasets (11ep + 30ep -> 41ep)"
echo "=============================================="
echo ""

# ------------------------------------------------------------------------------
# Load environment (.env) like other SO101 scripts
# ------------------------------------------------------------------------------
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

# Check HF_USER
if [ -z "${HF_USER:-}" ] || [ "$HF_USER" = "your_huggingface_username" ]; then
    echo -e "${RED}[ERROR]${NC} HF_USER is not set correctly in .env"
    echo "  Edit $SCRIPT_DIR/.env and set HF_USER to your HuggingFace username (e.g. DekuranC)"
    exit 1
fi

# Check HF_TOKEN
if [ -z "${HF_TOKEN:-}" ] || [ "$HF_TOKEN" = "your_huggingface_token_here" ]; then
    echo -e "${RED}[ERROR]${NC} HF_TOKEN is not set correctly in .env"
    echo "  Edit $SCRIPT_DIR/.env and set HF_TOKEN to your real HF token"
    exit 1
fi

echo -e "${BLUE}[INFO]${NC} Using HuggingFace account: ${HF_USER}"
echo ""

# ------------------------------------------------------------------------------
# Activate conda environment (same as hf_login.sh and 08_* scripts)
# ------------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/utils/activate_env.sh" ]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_DIR/utils/activate_env.sh"
    echo -e "${GREEN}[OK]${NC} Conda environment activated"
else
    echo -e "${YELLOW}[WARN]${NC} activate_env.sh not found at $SCRIPT_DIR/utils/activate_env.sh"
    echo "  Assuming you're already in the correct Python environment."
fi
echo ""

# ------------------------------------------------------------------------------
# Dataset repo configuration (overridable via env)
# ------------------------------------------------------------------------------
TS_11_REPO_DEFAULT="${HF_USER}/trash_sorting_11ep"
TS_30_REPO_DEFAULT="${HF_USER}/trash_sorting_30ep"
TS_COMBO_REPO_DEFAULT="${HF_USER}/trash_sorting_41ep_combo"

TS_11_REPO="${TS_11_REPO:-$TS_11_REPO_DEFAULT}"
TS_30_REPO="${TS_30_REPO:-$TS_30_REPO_DEFAULT}"
TS_COMBO_REPO="${TS_COMBO_REPO:-$TS_COMBO_REPO_DEFAULT}"
TS_SPLIT="${TS_SPLIT:-train}"

echo -e "${BLUE}[INFO]${NC} Configuration:"
echo "  Source 11-episode dataset : ${TS_11_REPO} (split=${TS_SPLIT})"
echo "  Source 30-episode dataset : ${TS_30_REPO} (split=${TS_SPLIT})"
echo "  Target 41-episode dataset : ${TS_COMBO_REPO}"
echo ""

# Export so embedded Python sees them via os.getenv(...)
export HF_USER HF_TOKEN TS_11_REPO TS_30_REPO TS_COMBO_REPO TS_SPLIT

# ------------------------------------------------------------------------------
# Run Python to combine + push to HF
# ------------------------------------------------------------------------------
python - << 'PYCODE'
import os
import sys

from datasets import load_dataset, concatenate_datasets
from huggingface_hub import login as hf_login, HfApi


def env(name: str, required: bool = True) -> str:
    value = os.getenv(name)
    if required and not value:
        print(f"[ERROR] Environment variable {name} is not set.", file=sys.stderr)
        sys.exit(1)
    return value


HF_USER = env("HF_USER")
HF_TOKEN = env("HF_TOKEN")
TS_11_REPO = env("TS_11_REPO")
TS_30_REPO = env("TS_30_REPO")
TS_COMBO_REPO = env("TS_COMBO_REPO")
TS_SPLIT = os.getenv("TS_SPLIT", "train")

print(f"[Python] Logging in to Hugging Face Hub as {HF_USER}...")
hf_login(token=HF_TOKEN)

api = HfApi()


def check_dataset_exists(repo_id: str):
    try:
        info = api.repo_info(repo_id, repo_type="dataset")
        print(f"[Python] ✅ Found dataset on HF: {info.id}")
    except Exception as e:
        print(f"[Python] ❌ Could not find dataset {repo_id}: {e}", file=sys.stderr)
        sys.exit(1)


print("[Python] Verifying source datasets exist...")
check_dataset_exists(TS_11_REPO)
check_dataset_exists(TS_30_REPO)

print(f"[Python] Loading source datasets with split='{TS_SPLIT}'...")
ds_11 = load_dataset(TS_11_REPO, split=TS_SPLIT)
ds_30 = load_dataset(TS_30_REPO, split=TS_SPLIT)

print(f"[Python] 11-episode dataset size : {len(ds_11)}")
print(f"[Python] 30-episode dataset size : {len(ds_30)}")
print(f"[Python] Column names           : {ds_11.column_names}")

print("[Python] Concatenating datasets...")
ds_combo = concatenate_datasets([ds_11, ds_30])
print(f"[Python] Combined dataset size   : {len(ds_combo)}")

print("[Python] Shuffling combined dataset (seed=42)...")
ds_combo = ds_combo.shuffle(seed=42)

print(f"[Python] Pushing combined dataset to: {TS_COMBO_REPO}")
ds_combo.push_to_hub(TS_COMBO_REPO)

print("[Python] ✅ Successfully pushed combined dataset.")
PYCODE

echo ""
echo -e "${GREEN}[SUCCESS]${NC} Combined dataset created and pushed:"
echo "  ${TS_COMBO_REPO}"
echo ""
echo "=============================================="
echo ""