#!/usr/bin/env bash
set -x

echo "atext,Preparing.. ,Preparing ..,Preparing. ." | nc -U /run/tinybox-screen.sock

# Check which gpus are installed
IS_NVIDIA_GPU=$(lspci | grep -i nvidia)

# clone tinygrad
su tiny -c "git clone https://github.com/tinygrad/tinygrad /home/tiny/tinygrad"

# install tinygrad and deps
pushd /home/tiny/tinygrad || exit
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

popd || exit

# remove the initial /opt/tinybox and clone the correct one into place
rm -rf /opt/tinybox
git clone "https://github.com/tinygrad/tinyos" /opt/tinybox

# rebuild the venv
pushd /opt/tinybox || exit
bash /opt/tinybox/build/build-venv.sh
if [ -n "$IS_NVIDIA_GPU" ]; then
  /opt/tinybox/build/venv/bin/python3 -m pip install nvidia-ml-py
fi
popd || exit

# install gum & mods
mkdir -p /etc/apt/keyrings
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | tee /etc/apt/sources.list.d/charm.list
apt update -y
apt install gum mods -y
cat <<EOF > /home/tiny/.config/mods/mods.conf
# Default model (gpt-3.5-turbo, gpt-4, ggml-gpt4all-j...).
default-model: tinychat
# Text to append when using the -f flag.
format-text:
  markdown: 'Format the response as markdown without enclosing backticks.'
  json: 'Format the response as json without enclosing backticks.'
  raw: ''
# List of predefined system messages that can be used as roles.
roles:
  "default": []
# Ask for the response to be formatted as markdown unless otherwise set.
format: false
# System role to use.
role: "default"
# Render output as raw text when connected to a TTY.
raw: false
# Quiet mode (hide the spinner while loading and stderr messages for success).
quiet: false
# Temperature (randomness) of results, from 0.0 to 2.0.
temp: 1.0
# TopP, an alternative to temperature that narrows response, from 0.0 to 1.0.
topp: 1.0
# Turn off the client-side limit on the size of the input into the model.
no-limit: true
# Wrap formatted output at specific width (default is 80)
word-wrap: 120
# Include the prompt from the arguments in the response.
include-prompt-args: false
# Include the prompt from the arguments and stdin, truncate stdin to specified number of lines.
include-prompt: 0
# Maximum number of times to retry API calls.
max-retries: 5
# Your desired level of fanciness.
fanciness: 10
# Text to show while generating.
status-text: Generating
# Default character limit on input to model.
max-input-chars: 12250
# Maximum number of tokens in response.
# max-tokens: 100
# Aliases and endpoints for OpenAI compatible REST API.
apis:
  tiny:
    base-url: http://127.0.0.1/v1
    models:
      tinychat:
        aliases: ["tinychat"]
EOF
chown tiny:tiny /home/tiny/.config/mods/mods.conf

# write the correct environment variables for tinychat to function correctly
cat <<EOF > /etc/tinychat.env
JITBEAM=4
TQDM_DISABLE=1
PYTHONUNBUFFERED=1
EOF

if [ -z "$IS_NVIDIA_GPU" ]; then
  tee --append /etc/tinychat.env <<EOF
AMD=1
EOF
else
  tee --append /etc/tinychat.env <<EOF
NV=1
EOF
fi
