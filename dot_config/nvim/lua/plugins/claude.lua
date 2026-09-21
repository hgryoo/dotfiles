-- Claude Code 연동.
--
-- 공식 IDE 확장은 VS Code/JetBrains 뿐이고, nvim 쪽은 coder/claudecode.nvim 이
-- 같은 WebSocket 프로토콜을 구현한다. 실질적인 이득은 둘이다: 선택 영역을 그대로
-- 넘기는 것과, Claude 가 만든 diff 를 에디터에서 수락/거절하는 것.
--
-- 계정이 둘이다 (dot_bash_aliases): cl → ~/.claude, clc → ~/.claude-cubrid.
-- CLI 는 자기 $CLAUDE_CONFIG_DIR/ide/*.lock 만 훑으므로, nvim 이 락을 어느 계정
-- 디렉터리에 쓰는지가 곧 "어느 계정에서 이 nvim 이 보이는지"가 된다. 기본값은 회사
-- (cubrid) 계정 — /data/cub_sys 와 /data/cubrid_cv 작업이 nvim 사용의 대부분이다.
-- 개인 계정으로 붙이려면 그 셸에서 CLAUDE_CONFIG_DIR=$HOME/.claude nvim 으로 띄운다.

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- 지연 로딩하지 않는다: 락 파일이 미리 있어야 옆 tmux pane 의 clc 가 /ide 로 찾는다.
    event = "VeryLazy",
    init = function()
      -- 서버가 올라가기 전에 정해져야 한다. 셸에서 이미 정해 왔으면 그쪽을 존중한다.
      if not vim.env.CLAUDE_CONFIG_DIR then
        vim.env.CLAUDE_CONFIG_DIR = vim.fn.expand("~/.claude-cubrid")
      end
    end,
    opts = {
      -- `claude` 는 대화형 셸에서 계정을 묻는 함수라(dot_bash_aliases) 터미널에서 부르면
      -- 프롬프트가 뜬다. 바이너리를 직접 부르고, 플래그는 clc 와 같게 맞춘다.
      terminal_cmd = vim.fn.expand("~/.local/bin/claude") .. " --dangerously-skip-permissions --effort xhigh",
    },
    keys = {
      { "<leader>ac", "<cmd>ClaudeCode<cr>", desc = "Claude 터미널 토글" },
      { "<leader>af", "<cmd>ClaudeCodeFocus<cr>", desc = "Claude 창으로 이동" },
      { "<leader>as", "<cmd>ClaudeCodeSend<cr>", mode = "v", desc = "선택 영역을 Claude 로" },
      { "<leader>ab", "<cmd>ClaudeCodeAdd %<cr>", desc = "현재 파일을 컨텍스트에 추가" },
      { "<leader>aa", "<cmd>ClaudeCodeDiffAccept<cr>", desc = "Claude diff 수락" },
      { "<leader>ad", "<cmd>ClaudeCodeDiffDeny<cr>", desc = "Claude diff 거절" },
      { "<leader>ao", "<cmd>ClaudeCodeStatus<cr>", desc = "Claude 연결 상태" },
    },
  },
}
