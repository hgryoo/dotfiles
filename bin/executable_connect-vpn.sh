#!/usr/bin/env bash
# connect-vpn.sh — CUBRID 사내망 VPN (openfortivpn) 접속.
#
# 자격증명은 이 파일에 없다. ~/.secrets.env 에서 읽는다
# (dotfiles/secrets.env.template 참고, .bashrc 가 자동으로 source 한다):
#
#   CUBRID_VPN_GATEWAY   호스트:포트
#   CUBRID_VPN_USERNAME  계정
#   CUBRID_VPN_CERT      --trusted-cert 로 넘길 인증서 지문
#   CUBRID_VPN_PASSWORD  (선택) 비우면 대화형으로 물어본다
#
# 사용법:
#   connect-vpn.sh              # 대화형 — 비밀번호를 직접 입력
#   connect-vpn.sh --persistent # 끊기면 10초 뒤 재접속
set -euo pipefail

[ -f "$HOME/.secrets.env" ] && . "$HOME/.secrets.env"

: "${CUBRID_VPN_GATEWAY:?~/.secrets.env 에 CUBRID_VPN_GATEWAY 를 설정하세요}"
: "${CUBRID_VPN_USERNAME:?~/.secrets.env 에 CUBRID_VPN_USERNAME 을 설정하세요}"
: "${CUBRID_VPN_CERT:?~/.secrets.env 에 CUBRID_VPN_CERT 를 설정하세요}"

command -v openfortivpn >/dev/null || {
  echo "openfortivpn 이 없습니다: sudo apt-get install -y openfortivpn" >&2
  exit 1
}

args=(
  "$CUBRID_VPN_GATEWAY"
  --username="$CUBRID_VPN_USERNAME"
  --trusted-cert "$CUBRID_VPN_CERT"
)
[ "${1:-}" = "--persistent" ] && args+=(--persistent=10)

sudo -v
# 비밀번호는 인자로 넘기지 않는다 — ps 에 그대로 보인다. stdin 으로 넣거나,
# 비어 있으면 openfortivpn 이 직접 물어보게 둔다.
if [ -n "${CUBRID_VPN_PASSWORD:-}" ]; then
  printf '%s\n' "$CUBRID_VPN_PASSWORD" | sudo openfortivpn "${args[@]}" --pppd-log=/dev/null
else
  sudo openfortivpn "${args[@]}"
fi
