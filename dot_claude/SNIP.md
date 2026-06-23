# snip - CLI Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations).
Replaces rtk. Binary: `~/.local/bin/snip`.

## Meta Commands (always use snip directly)

```bash
snip gain             # Show token savings report
snip gain --daily     # Time-based report (also --weekly)
snip discover         # Scan sessions for missed filter opportunities
snip config           # Show current configuration (db path, filters dir)
snip cc-economics     # Financial impact of token savings by API tier
snip check -- <cmd>   # Check whether a command would be filtered
snip proxy <cmd>      # Passthrough without filtering (for debugging)
```

## Installation Verification

```bash
snip --version        # Should show: snip vX.Y.Z
snip gain             # Should work (not "command not found")
which snip            # Verify correct binary (~/.local/bin/snip)
```

## Hook-Based Usage

All other commands are automatically rewritten by the Claude Code `PreToolUse`
hook (`snip hook` → `snip run -- <cmd>`). Claude Code never sees the
substitution; it receives compressed output as if the original command produced
it. Example: `git status` → filtered output (transparent, 0 tokens overhead).

## Hook / Filters

- Installed via `snip init`; removed via `snip init --uninstall`.
- 127 built-in YAML filters; custom filters live in `~/.config/snip/filters/`.
- Tracking DB: `~/.local/share/snip/tracking.db`.
```
