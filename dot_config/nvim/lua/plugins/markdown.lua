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

  -- render-markdown 이 못 그리는 것: 그림. roadmap 의 survey figure 는 SVG 143편이고
  -- (CLAUDE.md §2.9 — 인라인 <svg> 금지, assets/*.svg 링크만) mermaid 블록이 6편 더 있는데
  -- 버퍼 안에서는 전부 링크 텍스트로만 보인다. 그림까지 확인해야 할 때만 브라우저를 띄운다.
  -- 로컬 http 로 서빙하므로 assets/ 상대경로가 그대로 풀리고 mermaid 는 내장 지원이라,
  -- GitHub 에 push 하기 전 §2.9 그림을 확인하는 경로가 이것 하나로 끝난다.
  {
    "iamcco/markdown-preview.nvim",
    ft = { "markdown" },
    cmd = { "MarkdownPreview", "MarkdownPreviewStop", "MarkdownPreviewToggle" },
    -- 릴리스 바이너리를 받는 mkdp#util#install() 은 비동기라 lazy 가 완료 전에 성공으로 찍는다.
    -- node 가 이미 있으니 app/ 을 직접 빌드한다.
    build = "cd app && npx --yes yarn install",
    init = function()
      vim.g.mkdp_filetypes = { "markdown" }
      vim.g.mkdp_auto_close = 0 -- 버퍼를 닫아도 탭은 남긴다: 문서 여러 편을 번갈아 볼 때 창이 사라지면 성가시다
      vim.g.mkdp_theme = "light" -- §2.9 SVG 팔레트가 흰 배경 기준으로 그려져 있다

      -- ssh 로 들어와 있으면 브라우저를 띄우지 않는다. options.lua 의 클립보드와 같은
      -- 이유다 — 원격에서 띄운 크롬은 원격 화면에서 뜨고, 손에 닿는 건 앞의 머신이다.
      -- 대신 URL 만 받아 OSC52 로 로컬 클립보드에 넣는다(mkdp_browserfunc 가 지정되면
      -- app/server.js 는 openUrl 을 아예 부르지 않는다).
      if vim.env.SSH_TTY ~= nil then
        -- 포트를 비워두면 매번 랜덤이라 ssh -L 터널을 미리 걸 수 없다.
        --   ssh -L 8899:localhost:8899 <host>   (또는 ~/.ssh/config 의 LocalForward)
        vim.g.mkdp_port = "8899"
        vim.g.mkdp_browserfunc = "MkdpRemoteUrl"
        vim.g.mkdp_echo_preview_url = 1
        vim.cmd([[
          function! MkdpRemoteUrl(url) abort
            let @+ = a:url
            echomsg 'markdown preview: ' . a:url . ' (클립보드에 복사됨 — 터널 필요)'
          endfunction
        ]])
      end
    end,
    keys = {
      {
        "<leader>p",
        "<cmd>MarkdownPreviewToggle<CR>",
        ft = "markdown",
        desc = "브라우저 미리보기 (SVG·mermaid)",
      },
    },
  },
}
