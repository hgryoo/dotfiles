-- Claude Code 연동.
--
-- 공식 IDE 확장은 VS Code/JetBrains 뿐이고, nvim 쪽은 coder/claudecode.nvim 이
-- 같은 WebSocket 프로토콜을 구현한다. 실질적인 이득은 둘이다: 선택 영역을 그대로
-- 넘기는 것과, Claude 가 만든 diff 를 에디터에서 수락/거절하는 것.
--
-- 팀 공용 머신이라 Claude 환경은 하나다: 기본값인 ~/.claude (dot_bash_aliases).
-- CLI 는 자기 설정 디렉터리의 ide/*.lock 만 훑는데, CLAUDE_CONFIG_DIR 을 두지 않으면
-- CLI 와 이 플러그인이 둘 다 ~/.claude/ide 를 쓰므로 따로 맞출 것이 없다.
-- 여기서 CLAUDE_CONFIG_DIR 을 설정하면 안 된다 — 터미널로 띄운 claude 가 그 값을 물려받아
-- .claude.json 을 ~/.claude.json 대신 ~/.claude/.claude.json 에서 찾게 된다.

return {
  {
    "coder/claudecode.nvim",
    dependencies = { "folke/snacks.nvim" },
    -- 지연 로딩하지 않는다: 락 파일이 미리 있어야 옆 herdr pane 의 clh 가 /ide 로 찾는다.
    event = "VeryLazy",
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
