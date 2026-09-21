-- nvim — hgryoo
--
-- 설정은 lua/config/ 에, 플러그인 명세는 lua/plugins/ 에 둔다.
-- chezmoi 가 배포하므로 hgryoo-notebook 과 hgryoo-desktop 이 같은 상태를 갖는다.

vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lsp")

-- lazy.nvim 부트스트랩
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = { { import = "plugins" } },
  checker = { enabled = false },
  change_detection = { notify = false },
})
