#!/usr/bin/env bash
# connect-ts.sh — ssh to one of my tailnet machines, by name or by fragment.
#
# Tailscale already resolves `hgryoo-notebook` to an address, so the value here
# is everything around that: knowing which machines exist without opening the
# admin console, refusing to hang for 30 seconds on one that is asleep, and
# being able to type the part of the name you remember.
#
# Usage:
#   connect-ts                     list the machines and their state
#   connect-ts notebook            ssh there  (fragment match, case-insensitive)
#   connect-ts notebook uptime     run one command instead of a login shell
#   connect-ts -u root perf        ssh as another user
#   connect-ts --ip notebook       print the address and exit
#
# Android and offline peers are listed but refused as targets, with the reason.
set -euo pipefail

USER_AT="${USER}"
PRINT_IP=false

usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    -u|--user) USER_AT="$2"; shift 2 ;;
    --ip)      PRINT_IP=true; shift ;;
    -h|--help) usage; exit 0 ;;
    --)        shift; break ;;
    -*)        echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
    *)         break ;;
  esac
done

command -v tailscale >/dev/null || { echo "tailscale is not installed." >&2; exit 1; }

# One call to tailscale; everything else reads this.
PEERS=$(tailscale status --json 2>/dev/null) || {
  echo "tailscale is not running, or this machine is not on a tailnet." >&2; exit 1; }

peer_table() {  # name<TAB>ip<TAB>os<TAB>online<TAB>self
  printf '%s' "$PEERS" | python3 -c '
import json, sys
d = json.load(sys.stdin)
def row(p, is_self):
    ips = p.get("TailscaleIPs") or [""]
    print("\t".join([p.get("HostName", "?"), ips[0], p.get("OS", "?"),
                     "1" if (is_self or p.get("Online")) else "0",
                     "1" if is_self else "0"]))
row(d.get("Self", {}), True)
for p in sorted(d.get("Peer", {}).values(), key=lambda x: x.get("HostName", "")):
    row(p, False)
'
}

if [ $# -eq 0 ]; then
  printf '%-28s %-16s %-8s %s\n' MACHINE ADDRESS OS STATE
  printf '%.0s-' {1..64}; echo
  while IFS=$'\t' read -r name ip os online is_self; do
    state=$([ "$is_self" = 1 ] && echo "this machine" \
            || { [ "$online" = 1 ] && echo online || echo offline; })
    printf '%-28s %-16s %-8s %s\n' "$name" "$ip" "$os" "$state"
  done < <(peer_table)
  echo
  echo "connect-ts <name-fragment>   to ssh there"
  exit 0
fi

QUERY="$1"; shift

# Fragment match, case-insensitive. An exact name wins over a fragment, so
# `connect-ts tsx-n1` is not ambiguous just because tsx-n2 exists.
# -F'\t' matters: a machine name can contain spaces, and the default field
# split turned "형규의 S24 Ultra" into three fields, so nothing matched it.
MATCHES=$(peer_table | awk -F'\t' -v q="${QUERY,,}" '
  { name = tolower($1) }
  name == q { exact = $0 }
  index(name, q) { all = all $0 "\n" }
  END { if (exact != "") print exact; else printf "%s", all }')

COUNT=$(printf '%s' "$MATCHES" | grep -c . || true)
if [ "$COUNT" -eq 0 ]; then
  echo "No machine matches '$QUERY'. Known:" >&2
  peer_table | awk -F'\t' '{print "  " $1}' >&2
  exit 1
fi
if [ "$COUNT" -gt 1 ]; then
  echo "'$QUERY' matches more than one machine:" >&2
  printf '%s\n' "$MATCHES" | awk -F'\t' 'NF{print "  " $1}' >&2
  exit 1
fi

IFS=$'\t' read -r NAME IP OS ONLINE IS_SELF <<<"$MATCHES"

$PRINT_IP && { echo "$IP"; exit 0; }

[ "$IS_SELF" = 1 ] && { echo "$NAME is this machine." >&2; exit 1; }
[ "$ONLINE" = 1 ] || { echo "$NAME is offline — wake it first." >&2; exit 1; }
case "$OS" in
  android|ios) echo "$NAME runs $OS; there is no ssh to connect to." >&2; exit 1 ;;
esac

echo ">>> $USER_AT@$NAME ($IP)" >&2
exec ssh -o ConnectTimeout=15 "$USER_AT@$IP" "$@"
