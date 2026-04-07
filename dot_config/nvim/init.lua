-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- Basic settings (mirrors .vimrc)
vim.opt.number = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.ruler = true
vim.opt.cursorline = true
vim.opt.background = "dark"

-- Leader key
vim.g.mapleader = " "

-- Plugins (minimal starter set — add more as needed)
require("lazy").setup({
  -- Add plugins here, e.g.:
  -- { "nvim-treesitter/nvim-treesitter", build = ":TSUpdate" },
  -- { "neovim/nvim-lspconfig" },
})
