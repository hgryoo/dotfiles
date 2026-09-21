-- 문서 작업용. knowledge-base 778개 + cubrid_cv 1,178개, 합쳐서 md 가 1,900편이 넘고
-- 그중 735편이 frontmatter(title/category/tags)를 쓴다.
local KB = vim.env.KB_ROOT or "/data/hgryoo/knowledge-base"
local VAULT = "/data/cubrid_cv"

return {
  {
    -- VS Code 에서 .md 기본 뷰를 preview 로 둔 것과 같은 효과를 버퍼 안에서 낸다.
    "MeanderingProgrammer/render-markdown.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    ft = { "markdown" },
    opts = {},
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("hgryoo_markdown", { clear = true }),
        pattern = "markdown",
        callback = function()
          vim.opt_local.conceallevel = 2 -- render-markdown 가 마크업을 감추려면 필요하다
          vim.opt_local.colorcolumn = "" -- 산문에 120열 자는 방해만 된다
          -- 맞춤법 검사는 켜지 않는다: KO 미러가 376편이라 한국어가 전부 오류로 잡힌다.
        end,
      })
    end,
  },

  -- 문서 트리 전용 진입점. 코드 검색(<leader>fg)과 섞이면 md 1,900편이 결과를 덮는다.
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>fk", function() Snacks.picker.grep({ cwd = KB }) end, desc = "knowledge-base 검색" },
      {
        "<leader>fK",
        function() Snacks.picker.grep({ cwd = KB, search = "^title: ", live = false }) end,
        desc = "knowledge-base 문서 제목으로 (frontmatter)",
      },
      { "<leader>fv", function() Snacks.picker.grep({ cwd = VAULT }) end, desc = "cubrid_cv 검색" },
    },
  },
}
