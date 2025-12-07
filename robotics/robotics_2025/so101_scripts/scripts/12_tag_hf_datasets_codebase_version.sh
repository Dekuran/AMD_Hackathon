#!/bin/bash
################################################################################
# Script: 12_tag_hf_datasets_codebase_version.sh
# Purpose:
#   - Read codebase_version from meta/info.json on HF for:
#       HF_USER/trash_sorting_11ep
#       HF_USER/trash_sorting_30ep
#   - Ensure each dataset has a matching HF tag with that name.
#
# This script:
#   - Uses so101_scripts/.env for HF_USER / HF_TOKEN
#   - Activates the same conda env as other SO101 scripts
#   - Uses huggingface_hub (HfApi, hf_hub_download)
#
# Usage:
#   cd robotics/robotics_2025/so101_scripts
#   chmod +x scripts/12_tag_hf_datasets_codebase_version.sh
#   ./scripts/12_tag_hf_datasets_codebase_version.sh
################################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "============================================================"
echo "  Tag HF datasets with codebase_version from meta/info.json"
echo "============================================================"
echo ""

# ------------------------------------------------------------------------------
# Load .env (HF_USER / HF_TOKEN)
# ------------------------------------------------------------------------------
if [ ! -f "$SCRIPT_DIR/.env" ]; then
  echo -e "${RED}[ERROR]${NC} Missing $SCRIPT_DIR/.env"
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
  exit 1
fi

if [ -z "${HF_TOKEN:-}" ] || [ "$HF_TOKEN" = "your_huggingface_token_here" ]; then
  echo -e "${RED}[ERROR]${NC} HF_TOKEN is not set correctly in .env"
  exit 1
fi

echo -e "${BLUE}[INFO]${NC} HuggingFace user : ${HF_USER}"
echo ""

# ------------------------------------------------------------------------------
# Activate conda env
# ------------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/utils/activate_env.sh" ]; then
  # shellcheck source=/dev/null
  source "$SCRIPT_DIR/utils/activate_env.sh"
  echo -e "${GREEN}[OK]${NC} Conda environment activated"
else
  echo -e "${YELLOW}[WARN]${NC} activate_env.sh not found; assuming Python env is ready"
fi

echo ""

# Export token for Python
export HF_TOKEN

# ------------------------------------------------------------------------------
# Run Python logic
# ------------------------------------------------------------------------------
python - << 'PYCODE'
"""
Check dataset meta/info.json on HF and ensure there is a tag matching
the `codebase_version` field.
"""

from huggingface_hub import HfApi, hf_hub_download
import json
import os

hf_token = os.environ.get("HF_TOKEN")
hf_user = os.environ.get("HF_USER")

if not hf_token:
    raise SystemExit("HF_TOKEN not set in environment.")
if not hf_user:
    raise SystemExit("HF_USER not set in environment.")

api = HfApi(token=hf_token)

datasets = [
    f"{hf_user}/trash_sorting_11ep",
    f"{hf_user}/trash_sorting_30ep",
]

print("🔍 Checking dataset versions and tagging...\n")

for repo_id in datasets:
    print(f"--- {repo_id} ---")
    try:
        # Download info.json from HF
        info_path = hf_hub_download(
            repo_id=repo_id,
            filename="meta/info.json",
            repo_type="dataset",
            token=hf_token,
        )
        with open(info_path, "r") as f:
            info = json.load(f)

        version = info.get("codebase_version")
        if not version:
            # Fallback default if missing; adjust if needed
            version = "v3.0"
            print(f"  ⚠️  No codebase_version in info.json, defaulting to {version}")
        else:
            print(f"  📋 Found codebase_version in info.json: {version}")

        # Get existing tags
        try:
            refs = api.list_repo_refs(repo_id=repo_id, repo_type="dataset")
            tag_names = [t.name for t in (refs.tags or [])]
        except Exception as e:
            print(f"  ⚠️  Could not list existing tags: {e}")
            tag_names = []

        if version in tag_names:
            print(f"  ✅ Tag '{version}' already exists on {repo_id}")
        else:
            print(f"  🏷️  Creating tag '{version}' on {repo_id}...")
            api.create_tag(
                repo_id=repo_id,
                tag=version,
                repo_type="dataset",
            )
            print(f"  ✅ Successfully created tag '{version}' on {repo_id}")

    except Exception as e:
        print(f"  ❌ Error processing {repo_id}: {e}")

    print()

print("✅ Done. Datasets should now be tagged with their codebase_version.")
PYCODE

echo ""
echo "============================================================"
echo -e "${GREEN}[SUCCESS]${NC} Tag check/creation script finished."
echo "You can now re-run the LeRobotDataset check and training on the cloud."
echo "============================================================"
echo ""