# Train Lerobot Models on MI300x
This guide walks you through setting up environment for training imitation learning policies using [LeRobot](https://github.com/huggingface/lerobot) library on a DigitalOcean (DO) instance equipped with AMD MI300x GPUs and ROCm.

## Prerequisites
- A Hugging Face dataset repo ID containing your training data (`--dataset.repo_id=${HF_USER}/${DATASET_NAME}`).    
  If you don’t have an access token yet, you can sign up for Hugging Face here: https://huggingface.co/join .    
  After signing up, create an access token by visiting: https://huggingface.co/settings/tokens
- A wandb account to enable training visualization.    
  You can sign up for Wandb here: https://wandb.ai/signup    
  And visit here https://wandb.ai/authorize to create a token.
- Access to DO instance AMD Mi300x GPU
- Verify ROCm and GPU availability:
  ``` bash
  rocm-smi
  ```
  Example output:
  ``` bash
  ============================================= ROCm System Management Interface =============================================
  ======================================================= Concise Info =======================================================
  Device  Node  IDs              Temp        Power     Partitions          SCLK     MCLK     Fan  Perf  PwrCap  VRAM%  GPU%
                (DID,     GUID)  (Junction)  (Socket)  (Mem, Compute, ID)
  ============================================================================================================================
  0       1     0x74b5,   21947  67.0°C      737.0W    NPS1, SPX, 0        1280Mhz  1100Mhz  0%   auto  750.0W  49%    100%
  ============================================================================================================================
  =================================================== End of ROCm SMI Log ====================================================
  ```

## Environment Setup
### Option 1 (Recommended)
Use the pre-built docker image which includes all the necessary dependencies for training ACT and SmolVLA models.  
``` bash
docker run \
--device /dev/dri \
--device /dev/kfd \
--network host \
--ipc host \
--group-add video \
--cap-add SYS_PTRACE \
--security-opt seccomp=unconfined \
--workdir /lerobot \
--privileged \
-it -d \
--name lerobot xshan1/pytorch:rocm7.0_ubuntu24.04_py3.12_pytorch_release_2.7.1_lerobot_0.4.0
/bin/bash
```
You can add `--volume /path/on/host:/path/in/container` to create a shared folder between the host and the container, allowing datasets and trained models to be transferred easily.

### Option 2
Build environment from official ROCm Docker image. Here are the steps to prepare the setup.
#### Start the container using official ROCm backend supported PyTorch 2.7.1. 
``` bash
docker run \
--device /dev/dri \
--device /dev/kfd \
--network host \
--ipc host \
--group-add video \
--cap-add SYS_PTRACE \
--security-opt seccomp=unconfined \
--privileged \
-it -d \
--name lerobot rocm/pytorch:rocm7.0_ubuntu24.04_py3.12_pytorch_release_2.7.1
/bin/bash
```
**Note:** At now [2025/10], LeRobot depends on PyTorch version >=2.2.1, <2.8.0 (see [pyproject.toml](https://github.com/huggingface/lerobot/blob/v0.4.0/pyproject.toml#L79) ). You can add `--volume /path/on/host:/path/in/container` to create a shared folder between the host and the container, allowing datasets and trained models to be transferred easily.
#### Install FFmpeg 7.x
``` bash
add-apt-repository ppa:ubuntuhandbook1/ffmpeg7 # install PPA which contains ffmpeg 7.x
apt update
apt install ffmpeg -y
ffmpeg -version # verify version
```
#### Install LeRobot v0.4.0
Download and install LeRobot v0.4.0 in edit mode.This installs only the default dependencies.

``` bash
git clone https://github.com/huggingface/lerobot.git
cd lerobot

# let’s synchronize using this version
git checkout -b v0.4.0 v0.4.0
pip install -e .
```
Extra Features: To install additional functionality, use one of [them](https://github.com/huggingface/lerobot/blob/v0.4.0/pyproject.toml#L149).
``` bash
pip install -e ".[smolvla]"
pip install -e ".[pi]"
```
## Install and Configure Weights & Biases
Log into Weights & Biases (wandb) to enable experiment tracking and logging.
``` bash
pip install wandb -y
wandb login # enter your token to login
```
## Train models
1. Use the lerobot-train CLI from the lerobot library to train a robot control policy.
       
   Make sure to adjust the following arguments to your setup:
   - `--dataset.repo_id=${HF_USER}/${DATASET_NAME}`:    
     Replace this with the Hugging Face Hub repo ID where your dataset is stored, e.g., lerobot/svla_so100_pickplace.
     
   - `--policy.type=act`:    
     Specifies the policy configuration to use. `act` refers to `configuration_act.py`, which will automatically adapt to your dataset’s setup (e.g., number of motors and cameras).
     
   - `--output_dir=outputs/train/...`:    
     Directory where training logs and model checkpoints will be saved.
   - `--job_name=...`:    
     A name for this training job, used for logging and Weights & Biases. The name typically includes the model type (e.g., act, smolvla), the dataset name, and additional descriptive tags.
     
   - `--policy.device=cuda`:    
     Use cuda if training on an NVIDIA GPU. Use mps for Apple Silicon, or cpu if no GPU is available.
     
   - `--wandb.enable=true`:    
     Enables Weights & Biases for visualizing training progress. You must be logged in via wandb login before running this.

   - `--policy.push_to_hub=`:
     Enables automatic uploading of the trained policy to the Hugging Face Hub. You must specify `--policy.repo_id` (e.g., ${HF_USER}/{REPO_NAME}) if it is True.
     
    ``` bash
    lerobot-train \
      --dataset.repo_id=${HF_USER}/${DATASET_NAME} \
      --batch_size=128 \
      --steps=10000 \
      --output_dir=outputs/train/act_so101_3cube_10ksteps \ 
      --job_name=act_so101_3cube_10ksteps \
      --policy.device=cuda \
      --policy.type=act \ # change to smolvla or other models
      --policy.push_to_hub=false \
      --wandb.enable=true
   ```
   Notes:
   - If using a local dataset, add `--dataset.root=/path/to/dataset`.
   - Adjust `--batch_size` and `--steps` based on your hardware and dataset.
2. Monitoring & Output
    - Model checkpoints, logs, and training plots will be saved to the specified `--output_dir`
    - Training progress visualized in your wandb dashboard
## Login into Hugging Face Hub
After training is done login into the Hugging Face hub and upload the last checkpoint. You may refer to [here](https://github.com/huggingface/lerobot/blob/v0.4.0/README.md#add-a-pretrained-policy) for details.
``` bash
huggingface-cli login
huggingface-cli upload ${HF_USER}/{REPO_NAME} path/to/pretrained_model
# e.g. huggingface-cli upload ${HF_USER}/act_so101_3cube_10ksteps \
#  /lerobot/outputs/train/act_so101_3cube_10ksteps/checkpoints/last/pretrained_model
```
