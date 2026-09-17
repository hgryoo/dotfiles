#!/usr/bin/env bash
# OOM 사고(2026-07-27 13:50) 후속 조치
# 사용법:
#   sudo bash oom-fix.sh          # 1,2,3번 실행 (권장)
#   sudo bash oom-fix.sh --swap16 # 1,2,3 + 4번(swap 16GB) 까지
set -euo pipefail

GROW_SWAP=0
[[ "${1:-}" == "--swap16" ]] && GROW_SWAP=1

say() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }

# ---------------------------------------------------------------
say "1. ollama 무한 재시작 루프 정지"
# /data/local_llm 은 존재하지 않고, /data 는 99% 사용 중이라 모델 저장소로 부적합.
# 12일간 324,000회 재시작 실패 = 실사용 흔적 없음. 정지시킨다.
if systemctl is-enabled ollama &>/dev/null || systemctl is-active ollama &>/dev/null; then
  systemctl stop ollama || true
  systemctl disable ollama || true
  systemctl reset-failed ollama || true
  echo "ollama 정지 및 비활성화 완료."
else
  echo "ollama 이미 비활성 상태."
fi
echo "재사용하려면: OLLAMA_MODELS 를 여유 있는 경로로 바꾸고"
echo "  sudo mkdir -p <경로> && sudo chown -R ollama:ollama <경로>"
echo "  sudo systemctl enable --now ollama"

# ---------------------------------------------------------------
say "3-a. vm.swappiness 60 -> 10"
# swap 진입을 늦춰 스래싱 구간을 줄인다.
cat > /etc/sysctl.d/99-swappiness.conf <<'EOF'
# 데스크톱/개발 워크로드: 조기 swap-out 억제 (기본 60 -> 10)
vm.swappiness = 10
EOF
sysctl -p /etc/sysctl.d/99-swappiness.conf

# ---------------------------------------------------------------
say "3-b. earlyoom 설치 및 설정"
# OOM killer 는 swap 이 완전히 마른 뒤에야 동작한다(= 이번처럼 6분 멈춤).
# earlyoom 은 여유가 남아 있을 때 미리 최대 프로세스를 죽여 멈춤을 방지한다.
if ! command -v earlyoom &>/dev/null; then
  DEBIAN_FRONTEND=noninteractive apt-get install -y earlyoom
fi

cat > /etc/default/earlyoom <<'EOF'
# 여유 RAM < 8% 이고 여유 swap < 15% 이면 SIGTERM,
# 여유 RAM < 4% 이고 여유 swap < 8%  이면 SIGKILL.
# 기본 동작은 RSS 가 가장 큰 프로세스를 죽이는 것 —
# 이번 사고의 14.7GB 프로세스가 정확히 여기에 해당한다.
# --avoid: 이것들을 죽이면 원격 복구가 불가능해지므로 제외.
# (systemd 는 EnvironmentFile 값 안의 따옴표를 해석하지 않으므로 공백 없는 정규식만 사용)
EARLYOOM_ARGS="-r 3600 -m 8,4 -s 15,8 --avoid ^(systemd|sshd|Xorg|gnome-shell|dbus-daemon|tailscaled|tmux)"
EOF

systemctl enable --now earlyoom
systemctl restart earlyoom
systemctl --no-pager --lines=5 status earlyoom || true

# ---------------------------------------------------------------
say "3-c. systemd-oomd: swap 고갈 시 개입 활성화"
# 현재 -.slice 의 ManagedOOMSwap 이 auto(=꺼짐) 라서 이번에 발동하지 않았다.
# kill 로 바꾸면 swap 사용률 90% 초과 시 oomd 가 개입한다.
mkdir -p /etc/systemd/system/-.slice.d
cat > /etc/systemd/system/-.slice.d/50-oomd-swap.conf <<'EOF'
[Slice]
ManagedOOMSwap=kill
EOF

mkdir -p /etc/systemd/oomd.conf.d
cat > /etc/systemd/oomd.conf.d/50-tuning.conf <<'EOF'
[OOM]
SwapUsedLimit=85%
DefaultMemoryPressureLimit=50%
DefaultMemoryPressureDurationSec=20s
EOF

systemctl daemon-reload
systemctl restart systemd-oomd
echo "systemd-oomd 재설정 완료."

# ---------------------------------------------------------------
say "2. swap 비우기"
SWAP_USED_KB=$(awk '/^SwapTotal/{t=$2} /^SwapFree/{f=$2} END{print t-f}' /proc/meminfo)
AVAIL_KB=$(awk '/^MemAvailable/{print $2}' /proc/meminfo)
echo "swap 사용: $((SWAP_USED_KB/1024))MB / 가용 RAM: $((AVAIL_KB/1024))MB"

if (( AVAIL_KB < SWAP_USED_KB + 2097152 )); then
  echo "!! 가용 RAM 이 swap 사용량 + 2GB 미만입니다. swapoff 를 건너뜁니다."
  echo "!! 메모리를 쓰는 프로그램을 정리한 뒤 다시 실행하세요."
  SKIP_SWAP=1
else
  SKIP_SWAP=0
  echo "swapoff 진행 중 (수 분 걸릴 수 있음)..."
  swapoff -a
  echo "swapoff 완료."
fi

# ---------------------------------------------------------------
if (( GROW_SWAP == 1 && SKIP_SWAP == 0 )); then
  say "4. swap 8GB -> 16GB"
  # 경고: / 는 90% 사용 중(24GB 여유). 8GB 파일 삭제 후 16GB 생성 시 최종 여유 약 16GB(93%).
  AVAIL_DISK_GB=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
  echo "/ 여유 공간: ${AVAIL_DISK_GB}GB (기존 swap.img 8GB 회수 후 약 $((AVAIL_DISK_GB+8))GB)"
  if (( AVAIL_DISK_GB + 8 < 20 )); then
    echo "!! 여유 공간 부족. swap 확장을 건너뜁니다."
  else
    rm -f /swap.img
    fallocate -l 16G /swap.img
    chmod 600 /swap.img
    mkswap /swap.img
    echo "16GB swap 파일 생성 완료."
  fi
fi

if (( SKIP_SWAP == 0 )); then
  swapon -a
  echo "swap 재활성화 완료."
fi

# ---------------------------------------------------------------
say "최종 상태"
free -h
swapon --show
df -h /
echo
echo "swappiness: $(cat /proc/sys/vm/swappiness)"
echo "earlyoom:   $(systemctl is-active earlyoom)"
echo "oomd:       $(systemctl is-active systemd-oomd)"
echo "ollama:     $(systemctl is-enabled ollama 2>/dev/null || echo disabled)"
