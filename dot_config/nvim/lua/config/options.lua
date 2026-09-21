-- 기본 옵션. VS Code 쪽 설정(dot_config/Code/User/settings.json)과 같은 값을 쓴다 —
-- 두 에디터를 오가며 같은 파일을 만지므로 폭·들여쓰기·줄바꿈이 어긋나면 diff 가 지저분해진다.
local opt = vim.opt

-- 화면
opt.number = true
opt.cursorline = true
opt.signcolumn = "yes"
opt.colorcolumn = "120" -- VS Code rulers:[120]. CUBRID 포맷 규칙(indent -l120 / astyle --max-code-length=120)도 같다.
opt.wrap = true         -- VS Code wordWrap:"on"
opt.linebreak = true    -- 줄바꿈은 단어 경계에서
opt.scrolloff = 4
opt.termguicolors = true -- alacritty + tmux 가 truecolor (COLORTERM=truecolor)
opt.background = "dark"

-- 들여쓰기 (.vimrc / VS Code tabSize:4, insertSpaces 와 동일)
opt.expandtab = true
opt.tabstop = 4
opt.shiftwidth = 4
opt.autoindent = true
opt.smartindent = true

-- 검색
opt.hlsearch = true
opt.incsearch = true
opt.ignorecase = true
opt.smartcase = true

-- 창 분할은 오른쪽/아래로 — 읽던 자리가 밀리지 않는다
opt.splitright = true
opt.splitbelow = true

-- 되돌리기 이력을 파일로 남긴다. 세션을 닫았다 열어도 undo 가 살아 있다.
opt.undofile = true

-- 마우스: tmux 가 이미 `set -g mouse on` 이므로 nvim 도 켜 두어야 동작이 일관된다.
-- 터미널 자체 선택(= 터미널 복사)은 Shift+드래그.
opt.mouse = "a"
opt.mousemodel = "popup_setpos" -- 우클릭 컨텍스트 메뉴

-- 한글: D2Coding / Noto Sans Mono CJK 환경에서는 ambiwidth=single(기본값)이 맞다.
-- 여기서 double 로 바꾸면 박스 문자와 아이콘 정렬이 오히려 깨진다.

-- 클립보드. ssh 로 들어와 있으면 wl-copy 가 있어도 OSC52 를 쓴다 — 원격 머신의
-- 클립보드에 넣어 봐야 손에 닿는 건 앞에 있는 머신의 클립보드다. 로컬 세션에서는
-- wl-copy(wayland) / xclip 을 쓰고, 둘 다 없을 때도 OSC52 로 떨어진다.
opt.clipboard = "unnamedplus"
if vim.env.SSH_TTY ~= nil
  or (vim.fn.executable("wl-copy") == 0 and vim.fn.executable("xclip") == 0)
then
  local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
  if ok then
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end
