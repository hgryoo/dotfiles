local augroup = vim.api.nvim_create_augroup("hgryoo", { clear = true })

-- 저장할 때 줄 끝 공백 제거 (VS Code files.trimTrailingWhitespace 와 같은 동작).
-- markdown 은 제외한다 — 줄 끝 공백 두 개가 강제 줄바꿈이라 문서가 깨진다.
vim.api.nvim_create_autocmd("BufWritePre", {
  group = augroup,
  callback = function(ev)
    if vim.bo[ev.buf].filetype == "markdown" then
      return
    end
    local view = vim.fn.winsaveview()
    vim.cmd([[keeppatterns %s/\s\+$//e]])
    vim.fn.winrestview(view)
  end,
})

-- 파일을 다시 열면 마지막 커서 위치로
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 한글 입력 상태로 Insert 를 벗어나면 다음 명령이 한글로 들어간다.
-- ibus 가 있으면 Insert 를 나갈 때 영문 엔진으로 되돌린다 (비동기 — 입력을 막지 않는다).
if vim.fn.executable("ibus") == 1 then
  vim.api.nvim_create_autocmd("InsertLeave", {
    group = augroup,
    callback = function()
      vim.system({ "ibus", "engine", "xkb:us::eng" })
    end,
  })
end
