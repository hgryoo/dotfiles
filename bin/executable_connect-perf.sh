#!/usr/bin/env bash
# connect-perf.sh — 성능 측정용 사내 서버 SSH 접속.
#
# ~/.secrets.env 에서 읽는다:
#   PERF_HOST      root@<ip>
#   PERF_PASSWORD  (선택) 없으면 ssh 가 직접 물어본다
#
# 비밀번호가 설정돼 있으면 sshpass 를 쓴다. 호스트 키 검증을 끄지 않는다 —
# 사내망이라도 첫 접속에서 지문을 한 번 확인하는 편이 낫다. 재설치가 잦은
# 장비라면 ~/.ssh/config 에 그 호스트만 예외를 두는 쪽을 권한다.
set -euo pipefail

[ -f "$HOME/.secrets.env" ] && . "$HOME/.secrets.env"

: "${PERF_HOST:?~/.secrets.env 에 PERF_HOST 를 설정하세요}"

if [ -n "${PERF_PASSWORD:-}" ]; then
  command -v sshpass >/dev/null || {
    echo "sshpass 가 없습니다: sudo apt-get install -y sshpass" >&2
    exit 1
  }
  # -p 는 ps 에 비밀번호가 그대로 보인다. -e 로 환경변수를 통해 넘긴다.
  export SSHPASS="$PERF_PASSWORD"
  exec sshpass -e ssh "$PERF_HOST" "$@"
fi
exec ssh "$PERF_HOST" "$@"
