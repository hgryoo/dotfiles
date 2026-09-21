-- 키맵. leader 는 init.lua 에서 space 로 잡는다.
local map = vim.keymap.set

-- 검색 하이라이트 끄기
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "검색 하이라이트 끄기" })

-- 저장
map("n", "<leader>w", "<cmd>write<CR>", { desc = "저장" })

-- 터미널 모드 탈출
map("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "터미널 모드 나가기" })

-- 현재 위치를 `파일:라인` 으로 클립보드에 — Claude 세션(tmux 옆 pane)에 붙여넣기용.
map("n", "<leader>y", function()
  local ref = string.format("%s:%d", vim.fn.expand("%:."), vim.fn.line("."))
  vim.fn.setreg("+", ref)
  vim.notify(ref .. " 복사됨")
end, { desc = "파일:라인 복사 (Claude 에 붙여넣기)" })

-- 포맷: CUBRID 는 clang-format 이 아니라 cubindent 규칙(.c/.h=indent -l120,
-- .cpp=astyle gnu 2-space, .java=google-java-format)을 쓴다. LSP 포맷을 쓰면
-- 리뷰 diff 가 터지므로, 저장 시 자동 포맷은 걸지 않고 이 키맵으로만 부른다.
map("n", "<leader>cf", function()
  local file = vim.fn.expand("%:p")
  if vim.fn.executable("cubindent") == 0 then
    vim.notify("cubindent 가 PATH 에 없습니다 (scaffold/scripts/cubindent)", vim.log.levels.WARN)
    return
  end
  vim.cmd("write")
  vim.system({ "cubindent", file }, {}, function()
    vim.schedule(function()
      vim.cmd("checktime")
      vim.notify("cubindent 적용: " .. vim.fn.fnamemodify(file, ":t"))
    end)
  end)
end, { desc = "cubindent 로 포맷" })
