#!/usr/bin/env bash
set -x

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

# clone tinygrad
su tiny -c "git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad"

# install tinygrad and deps
pushd /home/tiny/tinygrad
su tiny -c "pip install -e ."
su tiny -c "pip install pillow tiktoken blobfile bottle tqdm"

# install pytorch
if [ -z "$IS_NVIDIA_GPU" ]; then
  su tiny -c "pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.0"
else
  su tiny -c "pip install torch torchvision torchaudio"
fi

# symlink datasets and weights
su tiny -c "ln -s /raid/datasets/imagenet extra/datasets/"
su tiny -c "ln -s /raid/weights ./"

popd

# remove the initial /opt/tinybox and clone the correct one into place
rm -rf /opt/tinybox
git clone "https://github.com/tinygrad/tinyos" /opt/tinybox

# rebuild the venv
pushd /opt/tinybox
bash /opt/tinybox/build/build-venv.sh
if [ -n "$IS_NVIDIA_GPU" ]; then
  /opt/tinybox/build/venv/bin/python3 -m pip install nvidia-ml-py
fi
popd

# write the correct environment variables for llmserve to function correctly
cat <<EOF > /etc/llmserve.env
JITBEAM=4
TQDM_DISABLE=1
PYTHONUNBUFFERED=1
EOF

if [ -z "$IS_NVIDIA_GPU" ]; then
  tee --append /etc/llmserve.env <<EOF
AMD=1
EOF
else
  tee --append /etc/llmserve.env <<EOF
NV=1
EOF
fi
