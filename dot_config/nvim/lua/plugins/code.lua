-- 코드 읽기용. CUBRID(C/C++)가 주 대상이다.
return {
  {
    -- master 브랜치는 "Neovim 0.12 는 지원하지 않는다"고 명시돼 있어서 main 을 쓴다.
    -- main 은 0.12.0+ 전용이고, 하이라이트를 자동으로 켜 주지 않으므로 직접 start 한다.
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("nvim-treesitter").setup({})
      require("nvim-treesitter").install({
        "c", "cpp", "java", "lua", "bash", "python",
        "markdown", "markdown_inline", "json", "yaml", "sql",
      })
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("hgryoo_ts", { clear = true }),
        pattern = {
          "c", "cpp", "java", "lua", "bash", "sh", "python",
          "markdown", "json", "yaml", "sql",
        },
        callback = function()
          pcall(vim.treesitter.start)
        end,
      })
    end,
  },

  -- 진단/참조 목록. 대형 트리에서 quickfix 보다 훑기 쉽다.
  {
    "folke/trouble.nvim",
    cmd = "Trouble",
    opts = {},
    keys = {
      { "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", desc = "진단 목록" },
      { "<leader>xb", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", desc = "이 파일 진단" },
      { "<leader>xr", "<cmd>Trouble lsp_references toggle<cr>", desc = "참조 목록" },
    },
  },
}
