#!/usr/bin/env bash
# /data, / 디스크 공간 회수 — 무손실/재생성 가능 항목만
# 사용법:
#   sudo bash disk-reclaim.sh --reserved   # 1단계만: ext4 예약 블록 축소 (삭제 없음, ~25GB)
#   sudo bash disk-reclaim.sh --caches     # 2단계만: 재생성 가능한 캐시 삭제 (~16GB)
#   sudo bash disk-reclaim.sh --all        # 1+2 단계
#
# 작업 트리(for-plan 256G, cub_sys 55G)와 build 디렉토리는 건드리지 않음.
set -euo pipefail

DO_RESERVED=0; DO_CACHES=0
for a in "$@"; do
  case "$a" in
    --reserved) DO_RESERVED=1 ;;
    --caches)   DO_CACHES=1 ;;
    --all)      DO_RESERVED=1; DO_CACHES=1 ;;
    *) echo "알 수 없는 옵션: $a"; exit 1 ;;
  esac
done
(( DO_RESERVED || DO_CACHES )) || { echo "옵션을 지정하세요 (--reserved / --caches / --all)"; exit 1; }

say() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }
before() { df -h / /data; }

say "시작 전 상태"; before

# ---------------------------------------------------------------
if (( DO_RESERVED )); then
  say "1. ext4 예약 블록 축소 (파일 삭제 없음)"
  # ext4 는 기본으로 전체의 5% 를 root 전용으로 예약한다.
  # 루트 파일시스템에서는 데몬이 디스크 풀 상황에서도 동작하게 해주는 안전장치지만,
  # /data 같은 순수 데이터 디스크에서는 25GB 를 그냥 놀리는 셈이다.

  # 장치명은 머신마다 다르다. 마운트 지점에서 찾아 쓴다 —
  # 이름을 박아두면 다른 머신에서 엉뚱한 파일시스템을 건드린다.
  reserve() {
    local mnt="$1" pct="$2" dev
    dev=$(findmnt -no SOURCE --target "$mnt") || { echo "[$mnt] 마운트 지점 없음, 건너뜀"; return; }
    if [[ $(findmnt -no FSTYPE --target "$mnt") != ext* ]]; then
      echo "[$mnt] ext 파일시스템이 아님($dev), 건너뜀"; return
    fi
    echo "[$mnt] $dev 예약률 -> ${pct}%"
    tune2fs -m "$pct" "$dev"
  }

  # /data: 5% -> 1%  (약 20GB 회수). 데이터 디스크이므로 안전.
  [[ -d /data ]] && reserve /data 1

  # /: 5% -> 3%  (약 5GB 회수). 루트이므로 완전히 없애지는 않는다.
  reserve / 3

  echo "완료."
fi

# ---------------------------------------------------------------
if (( DO_CACHES )); then
  say "2. 재생성 가능한 캐시 정리"

  # (a) vscode-cpptools IntelliSense DB — 10GB.
  #     삭제해도 VS Code 가 다시 인덱싱한다(첫 열기 시 느려짐).
  CPP=/data/workspace/.cache/vscode-cpptools
  if [[ -d $CPP ]]; then
    echo "[10G] $CPP 삭제"
    rm -rf "${CPP:?}"/*
  fi

  # (b) vscode-server CLI 구버전 — 2.9GB.
  #     최근 1개만 남기고 삭제. 원격 접속 시 필요분은 자동 재다운로드.
  VSC=/data/workspace/.cache/vscode-server/cli
  if [[ -d $VSC ]]; then
    echo "[~2.9G] $VSC 구버전 정리"
    find "$VSC" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' \
      | sort -rn | tail -n +2 | cut -d' ' -f2- | xargs -r rm -rf
  fi

  # (c) ccache — 5GB 한도에 꽉 찼는데 적중률이 21.5% 뿐이다.
  #     완전 삭제 대신 한도를 2GB 로 줄여 3GB 를 회수한다.
  if command -v ccache &>/dev/null; then
    echo "[~3G] ccache 한도 5G -> 2G 로 축소"
    CCACHE_DIR=/data/workspace/.cache/ccache sudo -u "#$(stat -c %u /data/workspace/.cache/ccache)" \
      ccache -M 2G 2>/dev/null || ccache -M 2G
    CCACHE_DIR=/data/workspace/.cache/ccache ccache -c 2>/dev/null || true
  fi

  echo "완료."
fi

# ---------------------------------------------------------------
say "완료 후 상태"; before
