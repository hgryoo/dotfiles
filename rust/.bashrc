# Load oh-my-bash
export OSH="$HOME/.oh-my-bash"
if [ -f "$OSH/oh-my-bash.sh" ]; then
  source "$OSH/oh-my-bash.sh"
fi

# Custom aliases & exports
[ -f ~/.bash_aliases ] && source ~/.bash_aliases
[ -f ~/.bash_exports ] && source ~/.bash_exports

# pyenv
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"

# Rust
export PATH="$HOME/.cargo/bin:$PATH"

# Cursor IDE
export PATH="$HOME/.cursor/bin:$PATH"

