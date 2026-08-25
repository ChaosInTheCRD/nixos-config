# This machine: `macbook-tailvisor-macos` (tailvisor macOS guest)

You are running inside a **macOS VM** (a "tailvisor" guest under Virtualization.framework),
not the physical MacBook. Agent/dev work happens here; the host stays clean. SIP is
**deliberately disabled** in this guest. The whole machine is declaratively managed by
nix-darwin from `~/Git/nixos-config` — see "Applying config changes" below before you try
to hand-edit dotfiles.

## Deploy the iOS app to the physical iPhone

The app (`~/Git/crate/ios/Shared Noise`) builds here and installs onto the real iPhone over
a USB tunnel the **host** holds. One command does build → install → relaunch:

```sh
cd ~/Git/crate/ios/"Shared Noise" && ios-deploy
```

- Uses Xcode 26.6 (`xcodebuild`), then `pymobiledevice3` to install over the host's tunnel
  and relaunch (Xcode-style kill+restart).
- **Prerequisites** (device state, not managed by nix): the iPhone is plugged into the
  **host**, unlocked, with Developer Mode on; the host's `pymobiledevice3 remote tunneld`
  launchd daemon is running (normally always up).
- **Check the tunnel first** if a deploy fails at the RSD step:
  `curl -s "http://[fd74:6169:6c76::1]:49151/"` should return the phone's RSD JSON
  (`tunnel-address` / `tunnel-port`). Empty/unreachable = phone unplugged or host tunneld down.
- Raw fallback script (same steps, no nix wrapper): `~/coredevice-tailnet/deploy.sh`.

The `ios-deploy` command is defined in nixos-config (`modules/ios-deploy`); it is on PATH,
not something to reinvent.

## Host ↔ guest clipboard

The hypervisor bridges the **host's** clipboard at `http://192.168.72.1:9550/clipboard`
(guest-only link). Shell aliases (defined in nixos-config `modules/shell/zsh.nix`):
- `hpaste` — pull the host clipboard into the guest (then ⌘V here).
- `hcopy`  — push the guest clipboard to the host (then ⌘V on the host).

(A background sync agent may also keep the two pasteboards in sync automatically, making plain
⌘C/⌘V work across both — text only; the bridge doesn't carry images.)

## Git

No YubiKey in the VM, so this guest **signs commits with a software SSH key**
(`~/.ssh/id_ed25519`, `gpg.format = ssh`) — not the host's GPG key. Push is over **HTTPS via
the `gh` credential helper**, so `gh` must be signed in (`gh auth status`). Commit messages
end with the standard `Co-Authored-By` / `Claude-Session` trailers.

## Applying config changes (nix-darwin) — everything is driven from nixos-config

This machine is nix-darwin. Dotfiles under `~/.config` (git, zsh, ghostty, kitty, sketchybar,
…) **and this very file** are **read-only symlinks into / managed by the nix store** — do NOT
`git config --global`, append to `~/.zshrc`, run `gh auth setup-git`, or hand-edit
`~/.claude/CLAUDE.md`; those either fail or get reverted. Change the source in
`~/Git/nixos-config` and apply:

```sh
make switch NIXNAME=macbook-tailvisor-macos
```

- Homebrew uses `cleanup = "zap"`: anything **not declared** in the config is uninstalled on
  every switch. Declare a brew/cask in `darwin/configuration.nix` before installing it, or a
  switch will wipe it. The guest's brew set mirrors the host's.
- Guest-only settings are gated on `config.tailvisor.guest` (nix) or a `*tailvisor*` hostname
  check (shell scripts).
- Push `nixos-config` with the gh helper if `git push` prompts:
  `git -c credential.helper='!gh auth git-credential' push`.

## Paseo

The paseo daemon listens on `:6767` and is reachable over the tailnet at
`http://tailvisor.tail7373cb.ts.net:6767`. Bind address and host allowlist are set via
`PASEO_LISTEN` / `PASEO_HOSTNAMES` env in nixos-config (`modules/paseo-darwin.nix`), and the
tailnet port is published by a NAT-PMP agent (`darwin/guest-paseo.nix`).

## Visual tells you're in the VM

Teal sketchybar with a "VM" badge, teal window borders, and a **right-side dock**. Window-
management hotkeys here use a **cmd+ctrl** prefix (the host uses alt).
