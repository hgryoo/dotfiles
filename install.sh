#!/usr/bin/env bash
set -e

DOTFILES=$HOME/.dotfiles

echo ">>> Create symbolic link..."
ln -sf ~/dotfiles ~/.dotfiles

echo ">>> Installing base packages..."
sudo apt-get update -y
sudo apt-get install -y curl git build-essential libssl-dev zlib1g-dev \
     libbz2-dev libreadline-dev libsqlite3-dev wget llvm \
     libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev libffi-dev liblzma-dev

echo ">>> Linking dotfiles..."
ln -sf $DOTFILES/bash/.bashrc ~/.bashrc
ln -sf $DOTFILES/vim/.vimrc ~/.vimrc
ln -sf $DOTFILES/git/.gitconfig ~/.gitconfig

echo ">>> Installing oh-my-bash..."
bash -c "$(wget https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh -O -)"

echo ">>> Installing Python 3.12 via pyenv..."
if ! command -v pyenv &>/dev/null; then
  curl https://pyenv.run | bash
  export PATH="$HOME/.pyenv/bin:$PATH"
  eval "$(pyenv init -)"
  pyenv install 3.12.5
  pyenv global 3.12.5
fi

echo ">>> Installing Rust environment..."
bash $DOTFILES/rust/setup_rust_env.sh

echo ">>> Installing dev tools for CUBRID..."
sudo bash $DOTFILES/cubrid/setup_cubrid_env.sh

echo "✅ All environments installed successfully!"

