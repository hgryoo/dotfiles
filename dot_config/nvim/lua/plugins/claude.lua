-- Claude Code 연동.
--
-- 공식 IDE 확장은 VS Code/JetBrains 뿐이고, nvim 쪽은 coder/claudecode.nvim 이
-- 같은 WebSocket 프로토콜을 구현한다. 실질적인 이득은 둘이다: 선택 영역을 그대로
-- 넘기는 것과, Claude 가 만든 diff 를 에디터에서 수락/거절하는 것.
--
-- 팀 공용 머신이라 Claude 환경은 하나다 (dot_bash_aliases): ~/.claude-cubrid.
-- CLI 는 자기 $CLAUDE_CONFIG_DIR/ide/*.lock 만 훑으므로, nvim 도 락을 같은
-- 디렉터리에 써야 옆 pane 의 claude 가 이 nvim 을 찾는다. 셸은 CLAUDE_CONFIG_DIR 을
-- export 하지만, 셸을 거치지 않고 뜬 nvim 을 위해 여기서도 기본값을 둔다.

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- 지연 로딩하지 않는다: 락 파일이 미리 있어야 옆 herdr pane 의 clh 가 /ide 로 찾는다.
    event = "VeryLazy",
    init = function()
      -- 서버가 올라가기 전에 정해져야 한다. 셸에서 이미 정해 왔으면 그쪽을 존중한다.
      if not vim.env.CLAUDE_CONFIG_DIR then
        vim.env.CLAUDE_CONFIG_DIR = vim.fn.expand("~/.claude-cubrid")
      end
    end,
    opts = {
      -- `claude` 는 셸 함수 없이 바이너리 그대로다(설치 위치는 머신마다 다르다 —
      -- 여기선 npm 전역 /usr/local/bin). PATH 에서 찾고, 플래그는 clh 와 같게 맞춘다.
      terminal_cmd = "claude --dangerously-skip-permissions --effort xhigh",
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
