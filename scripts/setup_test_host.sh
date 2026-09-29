#!/usr/bin/env bash
# setup_test_host.sh — System settings for the CUBRID DBMS test host
#                      (weekly functional/performance tests on Sat/Sun,
#                       new-feature performance experiments).
#
# What this applies (idempotent — safe to re-run):
#
#   1. tuned profile `cubrid-test` = throughput-performance, plus:
#        C-states    deepest allowed state is C2 (18 us wake-up; C3 takes 350 us)
#        THP         madvise (was always)
#        dirty pages writeback starts at 256 MB, writers block at 2 GB
#                    (was 10% / 40% of RAM = about 6 GB / 23 GB)
#        autogroup   off — CPU time is shared per thread, not per terminal session
#        CPU boost   stays on; turn it off for a run with ~/bin/cpu-boost off
#      GNOME's "Performance" power mode (tuned-ppd) is mapped to it too.
#   2. sysctl: core files go to /data/cores/core.<exe>.<pid>.<time>
#      (systemd-coredump drops cores larger than 1 GB — a cub_server with a large
#      buffer pool), and perf can profile the kernel as a normal user.
#   3. Open files: soft limit 65536 (was 1024) for logins, services and terminals.
#      Takes effect after the next login; a reboot is simplest.
#   4. Background jobs that would run on a test day:
#        off   dnf-makecache, plocate-updatedb, raid-check (no md RAID here),
#              GNOME Software automatic update downloads
#        moved fstrim → Wednesday 03:00, no catch-up at boot
#   5. /data/cores and /data/history (the Claude change log).
#
# Run it as the normal user, not with sudo; it calls sudo for the system parts.
#
# Usage:
#   scripts/setup_test_host.sh
set -euo pipefail

[[ $EUID -ne 0 ]] || { echo "Run as the normal user, not root." >&2; exit 1; }
[[ -d /data ]]    || { echo "/data does not exist." >&2; exit 1; }
ME=$(id -un)

say() { printf '\n\033[1;36m=== %s ===\033[0m\n' "$*"; }

sudo -v

# ---------------------------------------------------------------------------
say "1. tuned profile cubrid-test"
# ---------------------------------------------------------------------------
sudo install -d /etc/tuned/profiles/cubrid-test
sudo tee /etc/tuned/profiles/cubrid-test/tuned.conf >/dev/null <<'EOF'
# Written by ~/dotfiles/scripts/setup_test_host.sh
[main]
summary=CUBRID DBMS test host: throughput-performance with stable latency
include=throughput-performance

[cpu]
# Deepest allowed C-state is C2 (18 us wake-up). C3 takes 350 us.
force_latency=cstate.name:C2|18

[vm]
transparent_hugepages=madvise
# Writeback starts at 256 MB; writers block at 2 GB (about 1 s of NVMe writes).
dirty_background_bytes=268435456
dirty_bytes=2147483648

[sysctl]
# Share CPU time per thread, not per terminal session.
kernel.sched_autogroup_enabled=0
EOF
# Without this, tuned-ppd puts throughput-performance back for "Performance".
sudo sed -i 's/^performance=.*/performance=cubrid-test/' /etc/tuned/ppd.conf
sudo systemctl try-restart tuned-ppd
sudo tuned-adm profile cubrid-test

# ---------------------------------------------------------------------------
say "2. core files → /data/cores, kernel profiling"
# ---------------------------------------------------------------------------
sudo install -d -m 1777 -o "$ME" -g "$ME" /data/cores
sudo tee /etc/sysctl.d/90-cubrid-test.conf >/dev/null <<'EOF'
# Written by ~/dotfiles/scripts/setup_test_host.sh
# Core files go to /data/cores. systemd-coredump (50-coredump.conf) drops
# cores larger than 1 GB.
kernel.core_pattern = /data/cores/core.%e.%p.%t
# perf can profile the kernel as a normal user.
kernel.perf_event_paranoid = 1
kernel.kptr_restrict = 0
EOF
sudo sysctl -q -p /etc/sysctl.d/90-cubrid-test.conf

# ---------------------------------------------------------------------------
say "3. open files: soft 65536"
# ---------------------------------------------------------------------------
sudo tee /etc/security/limits.d/90-cubrid-test.conf >/dev/null <<'EOF'
# Written by ~/dotfiles/scripts/setup_test_host.sh
# Tests with many connections need more than 1024 open files.
*    soft    nofile    65536
EOF
for m in system user; do
  sudo install -d "/etc/systemd/$m.conf.d"
  sudo tee "/etc/systemd/$m.conf.d/90-cubrid-test.conf" >/dev/null <<'EOF'
# Written by ~/dotfiles/scripts/setup_test_host.sh
[Manager]
DefaultLimitNOFILE=65536:524288
EOF
done
sudo systemctl daemon-reexec

# ---------------------------------------------------------------------------
say "4. background jobs on test days (Sat/Sun)"
# ---------------------------------------------------------------------------
sudo systemctl disable --now dnf-makecache.timer plocate-updatedb.timer raid-check.timer
sudo install -d /etc/systemd/system/fstrim.timer.d
sudo tee /etc/systemd/system/fstrim.timer.d/90-cubrid-test.conf >/dev/null <<'EOF'
# Written by ~/dotfiles/scripts/setup_test_host.sh
# Weekly tests run on Saturday and Sunday: TRIM on Wednesday instead.
[Timer]
OnCalendar=
OnCalendar=Wed *-*-* 03:00:00
RandomizedDelaySec=0
# Do not catch up a missed run at boot; it could land on a test day.
Persistent=false
EOF
sudo systemctl daemon-reload
sudo systemctl enable fstrim.timer
sudo systemctl restart fstrim.timer
if [[ -n ${DBUS_SESSION_BUS_ADDRESS:-} ]]; then
  gsettings set org.gnome.software download-updates false
else
  echo "No GNOME session: run this later from a desktop terminal:"
  echo "  gsettings set org.gnome.software download-updates false"
fi

# ---------------------------------------------------------------------------
say "5. /data/history"
# ---------------------------------------------------------------------------
sudo install -d -m 0755 -o "$ME" -g "$ME" /data/history

# ---------------------------------------------------------------------------
say "Result"
# ---------------------------------------------------------------------------
printf '%-11s %s\n' \
  tuned      "$(tuned-adm active | sed 's/.*: //')" \
  C-state    "cpu_dma_latency=$(sudo od -An -tu4 /dev/cpu_dma_latency | tr -d ' ') us" \
  THP        "$(cat /sys/kernel/mm/transparent_hugepage/enabled)" \
  dirty      "background=$(sysctl -n vm.dirty_background_bytes) limit=$(sysctl -n vm.dirty_bytes)" \
  autogroup  "$(sysctl -n kernel.sched_autogroup_enabled)" \
  boost      "$(cat /sys/devices/system/cpu/cpufreq/boost)" \
  core       "$(sysctl -n kernel.core_pattern)" \
  perf       "paranoid=$(sysctl -n kernel.perf_event_paranoid) kptr_restrict=$(sysctl -n kernel.kptr_restrict)" \
  timers-off "$(systemctl is-enabled dnf-makecache.timer plocate-updatedb.timer raid-check.timer | paste -sd' ')" \
  fstrim     "$(systemctl show fstrim.timer -p NextElapseUSecRealtime --value)" \
  nofile     "log in again (or reboot) to get soft 65536"
