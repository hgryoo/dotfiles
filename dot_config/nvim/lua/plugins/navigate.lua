-- /data 안을 오가기 위한 것들.
-- 데스크톱 히스토리 기준으로 `cd /data/workspace/for-plan/pl/CBRD-27287` 1,582회,
-- `cd /data/cub_sys/projects/cubrid-testkit` 1,103회 — 시간을 가장 많이 먹는 동작이 경로 이동이다.
return {
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },   -- CUBRID 소스에는 만 줄짜리 파일이 흔하다
      quickfile = { enabled = true },
      explorer = { enabled = true },
      picker = {
        enabled = true,
        sources = {
          -- follow 가 핵심. /data/workspace 는 심링크로 짜인 레이아웃이라
          -- 이게 없으면 topic/* 아래 프로젝트 상당수가 검색에 잡히지 않는다.
          files = { follow = true, hidden = true },
          grep = { follow = true, hidden = true },
        },
      },
    },
    keys = {
      { "<leader><space>", function() Snacks.picker.smart() end, desc = "파일 찾기 (버퍼+최근+파일)" },
      { "<leader>ff", function() Snacks.picker.files() end, desc = "파일" },
      { "<leader>fg", function() Snacks.picker.grep() end, desc = "내용 검색 (grep)" },
      { "<leader>fb", function() Snacks.picker.buffers() end, desc = "버퍼" },
      { "<leader>fr", function() Snacks.picker.recent() end, desc = "최근 파일" },
      { "<leader>fp", function() Snacks.picker.zoxide() end, desc = "프로젝트 (zoxide)" },
      { "<leader>e",  function() Snacks.explorer() end, desc = "파일 탐색기" },
    },
  },

  -- 디렉터리를 버퍼처럼 편집한다. 깊은 경로를 오르내릴 때 탐색기보다 빠르다.
  {
    "stevearc/oil.nvim",
    lazy = false,
    opts = { view_options = { show_hidden = true } },
    keys = { { "-", "<cmd>Oil<cr>", desc = "상위 디렉터리 열기 (oil)" } },
  },

  -- 이슈 하나를 보는 동안 오가는 서너 개 파일을 고정해 둔다.
  {
    "ThePrimeagen/harpoon",
    branch = "harpoon2",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- <leader>m (mark). 원래 <leader>a 였는데 claudecode 의 <leader>a* 와 접두사가
    -- 겹쳐서, 둘 다 매핑돼 있으면 nvim 이 timeoutlen 만큼 기다렸다 결정한다.
    keys = {
      { "<leader>ma", function() require("harpoon"):list():add() end, desc = "harpoon 에 추가" },
      { "<leader>mm", function() local h = require("harpoon") h.ui:toggle_quick_menu(h:list()) end, desc = "harpoon 목록" },
      { "<leader>m1", function() require("harpoon"):list():select(1) end, desc = "harpoon 1" },
      { "<leader>m2", function() require("harpoon"):list():select(2) end, desc = "harpoon 2" },
      { "<leader>m3", function() require("harpoon"):list():select(3) end, desc = "harpoon 3" },
      { "<leader>m4", function() require("harpoon"):list():select(4) end, desc = "harpoon 4" },
    },
    config = function() require("harpoon"):setup() end,
  },

  -- 프로젝트(=cwd)별 세션. tmux 세션을 프로젝트별로 쓰는 방식과 1:1로 맞는다.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>qs", function() require("persistence").load() end, desc = "이 디렉터리 세션 복원" },
      { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "마지막 세션 복원" },
      { "<leader>qS", function() require("persistence").select() end, desc = "세션 고르기" },
    },
  },

  -- leader 키를 새로 익히는 중이므로, 눌러 놓고 기다리면 뭐가 있는지 보여주는 쪽이 낫다.
  { "folke/which-key.nvim", event = "VeryLazy", opts = {} },
}
