#!/usr/bin/env bash
# connect-aws.sh — cubvec EC2 인스턴스 SSH 접속.
#
# ~/.secrets.env 에서 읽는다:
#   CUBVEC_EC2_HOST   ubuntu@ec2-...compute.amazonaws.com
#   CUBVEC_EC2_KEY    (선택) 키 파일 경로, 기본값 ~/cubvec_keypair1.pem
#
# 키 파일 자체는 dotfiles 에 없다. 기존 머신에서 따로 복사해 와야 한다:
#   scp <old-host>:~/cubvec_keypair1.pem ~/ && chmod 400 ~/cubvec_keypair1.pem
set -euo pipefail

[ -f "$HOME/.secrets.env" ] && . "$HOME/.secrets.env"

: "${CUBVEC_EC2_HOST:?~/.secrets.env 에 CUBVEC_EC2_HOST 를 설정하세요}"
KEY="${CUBVEC_EC2_KEY:-$HOME/cubvec_keypair1.pem}"

[ -f "$KEY" ] || { echo "키 파일이 없습니다: $KEY" >&2; exit 1; }
exec ssh -i "$KEY" "$CUBVEC_EC2_HOST" "$@"
