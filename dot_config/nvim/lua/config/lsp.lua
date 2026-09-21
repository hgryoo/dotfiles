-- LSP. nvim 0.11+ 의 기본 API(vim.lsp.config/enable)를 쓰므로 nvim-lspconfig 는 두지 않는다.
-- 서버가 clangd 하나뿐이라 플러그인을 더 얹을 이유가 없다.

vim.diagnostic.config({
  virtual_text = true,
  severity_sort = true,
  float = { border = "rounded" },
})

-- clangd 가 없으면 아무것도 등록하지 않는다 (지금 두 머신 모두 미설치 — apt install clangd).
if vim.fn.executable("clangd") == 1 then
  vim.lsp.config("clangd", {
    cmd = {
      "clangd",
      "--background-index",       -- CUBRID 규모에서는 미리 인덱싱해 두는 편이 낫다
      "--header-insertion=never", -- 자동 #include 삽입은 리뷰 diff 에 잡음만 만든다
      "--completion-style=detailed",
      "--pch-storage=memory",
    },
    filetypes = { "c", "cpp", "objc", "objcpp", "cuda" },
    -- CUBRID 는 빌드 디렉터리가 소스 트리 밖(/data/cub_sys/devbuild)이라 clangd 가
    -- compile_commands.json 을 스스로 찾지 못한다. 저장소 루트에 심링크를 두고 쓴다:
    --   ln -s ../devbuild/compile_commands.json /data/cub_sys/cubrid/compile_commands.json
    --   echo compile_commands.json >> .git/info/exclude
    root_markers = { "compile_commands.json", "CMakePresets.json", ".git" },
  })
  vim.lsp.enable("clangd")
end

-- 포맷은 LSP 로 하지 않는다. CUBRID 규칙은 clang-format 이 아니라 cubindent
-- (.c/.h = indent -l120, .cpp = astyle --style=gnu --indent=spaces=2, .java = google-java-format)
-- 이라서, clangd 포맷을 쓰면 프로젝트 스타일과 어긋난 diff 가 나온다. <leader>cf 를 쓸 것.

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("hgryoo_lsp", { clear = true }),
  callback = function(ev)
    local buf = ev.buf
    local function map(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
    end
    -- 0.11 부터 K(문서), grn(이름 변경), gra(코드 액션), grr(참조)는 기본 제공된다.
    map("gd", vim.lsp.buf.definition, "정의로 이동")
    map("gD", vim.lsp.buf.declaration, "선언으로 이동")
    map("<leader>cs", vim.lsp.buf.document_symbol, "파일 내 심볼")

    -- 플러그인 없는 자동완성 (0.11+ 내장)
    local client = vim.lsp.get_client_by_id(ev.data.client_id)
    if client and client.server_capabilities and client.server_capabilities.completionProvider then
      if vim.lsp.completion and vim.lsp.completion.enable then
        pcall(vim.lsp.completion.enable, true, client.id, buf, { autotrigger = true })
      end
    end
  end,
})
