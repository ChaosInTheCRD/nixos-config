# LLM sandbox VM setup

Turns a corp workstation VM (llm-sandbox purpose) into a fully-provisioned,
always-on AI agent box, running as your own user (`chaosinthecrd`):

- your home-manager environment (zsh, nvim, git, all `pkgs/` toolsets) via the
  `llm@<arch>` flake profile
- [paseo](https://github.com/getpaseo/paseo) daemon as a supervised systemd
  user service on port `6767`, reachable from any tailnet device (laptop,
  phone) and surviving crashes/reboots
- codex + opencode from nixpkgs, wired to the Aperture LLM gateway at
  `http://ai` (claude already configured via `~/.claude/settings.json`)
- `expose <port>` to publish localhost services to the tailnet
- corp git workflow: `aif` push/fetch from the Mac, rogitproxy for private
  repos, maintner `gh`/`mn` for GitHub data without credentials

Runtime paseo state (`~/.paseo/config.json` — listen address, hostnames,
pairings) is owned by paseo itself and never touched by this config.

## Bootstrap

From this repo on the Mac:

```bash
make bootstrap-llm                 # VM name comes from ~/.config/llm-vm/env (private dots repo)
VM=some-other-vm make bootstrap-llm
```

This ssh-es in as `$USER` and runs `scripts/bootstrap-llm-vm.sh`, which is
idempotent — re-run it any time to pick up config changes. It installs Nix if
missing, applies `homeConfigurations."llm@<arch>"`, enables lingering
(services survive reboot), clones `tailscale/corp` via rogitproxy to
`~/Git/corp` if absent, and builds maintner's `gh` + `mn` into `~/.local/bin`.

To update later, either re-run the bootstrap or, on the VM:

```bash
cd ~/Git/nixos-config && git pull
home-manager switch -b backup --flake ".#llm@x86_64-linux" --impure
```

## Connecting to paseo

```bash
# CLI from the Mac
paseo --host <vm-name>:6767 ls

# Desktop app: Settings -> Connections -> add host
# Phone: pair against http://<vm-name>:6767
#        (or via the app.paseo.sh relay)
```

Service management on the VM: `systemctl --user {status,restart} paseo`,
logs via `journalctl --user -u paseo` or `~/.paseo/daemon.log`.

## Exposing service ports

Anything bound to localhost on the VM can be published to the tailnet:

```bash
kubectl proxy &          # listens on 127.0.0.1:8001
expose 8001              # now reachable at <vm>:8001 from any tailnet device
expose -l                # list exposed ports
expose -d 8001           # stop
```

Under the hood this is an `expose@<port>` systemd user unit running socat, so
exposures survive until stopped and restart on failure.

## Sharing Mac-side connections with the VM (vmshare)

The reverse direction: give agents on the VM access to something only your
Mac can reach (e.g. a kubectl proxy against a VPN-gated cluster). From the
Mac:

```bash
kubectl proxy &            # binds 127.0.0.1:8001 on the Mac, injects your auth
vmshare 8001               # holds the terminal; Ctrl-C to stop
vmshare 8001 8002 8003     # multiple ports
```

`vmshare` (in `modules/shell/shell_functions`) is `ssh -N -R` under the hood:
each port lands on the **VM's loopback only**, so agents on the VM reach it at
`http://127.0.0.1:8001` but nothing else on the tailnet can — your cluster
credentials are never published. The tunnel lives as long as the command runs.

## Moving code: aif

[`aif`](https://github.com/tailscale/corp/tree/main/misc/aif) syncs branches
between the Mac and the VM over ssh+git. Install on the Mac:

```bash
cd ~/Git/corp && ./tool/go install tailscale.io/misc/aif
```

aif defaults to SSH user `ubuntu`, but this VM uses `chaosinthecrd` — so on
the Mac set (e.g. in shell_exports):

```bash
export AIF_SSH_USER=chaosinthecrd
```

It auto-discovers your running llm-sandbox VM from workstations.corp.ts.net
and targets `<user>@<vm>:<repo path relative to $HOME>` — so a repo must live
at the same `$HOME`-relative path on both machines (e.g. `~/Git/nixos-config`
on both). Note: the remote URL is created once and persisted as the `ai` git
remote; if it was created before setting `AIF_SSH_USER`, fix it with
`git remote remove ai`.

```bash
aif push        # Mac -> VM: push current branch into the VM's working tree
aif             # VM -> Mac: fetch the branch back and hard-reset to it
aif <branch>    # switch/create <branch>, then fetch+reset
```

Pushing into the checked-out branch works because the server git config sets
`receive.denyCurrentBranch = updateInstead` (updates the VM's working tree in
place — the VM copy must be clean for the push to apply).

## Shipping a branch: ship

`ship` (in `bin/`) closes the loop from agent branch to GitHub without
letting unsigned commits through. VM-made commits are unsigned by design
(the signing key lives on the Mac); `ship`:

1. re-signs any unsigned commits in `base..HEAD` in place
   (`git rebase --force-rebase --gpg-sign` — one YubiKey touch, messages
   and structure preserved; base defaults to origin/main)
2. pushes the branch to GitHub with `--force-with-lease`
3. syncs the re-signed history back to the VM (`aif push -f`) and runs
   `work sync` there so issue work dirs re-map to the branch

So the usual flow is: `aif <branch>` to pull agent work down, restructure
commits however you like (or not at all), then `ship`.

As a backstop, `install-push-guard` (run once inside a repo) installs a
pre-push hook that rejects pushes to github.com containing unsigned
commits. In repos whose hooks are managed by ts-git-hook (corp,
tailscale) it installs as `pre-push.local`, which the ts-git-hook
dispatcher chains to. Bypass deliberately with `git push --no-verify`.

## Board workflow: board / take / chop / taken

CLIs in `bin/` (on PATH via shell_exports) that drive the Kubernetes &
Containers project board (tailscale org project 173) through maintner and
dispatch paseo agents on the VM:

```bash
board                        # kanban view: Not Started / In Progress / In Review / Done
board --label Refined        # any filter applies across all columns
board --status "In Review"   # single column, flat
board --flat                 # old flat list (Not Started + unassigned)
board show corp#38175        # full issue: description + comments (no browser)

take corp#45571              # pull issue via maintner, open $EDITOR for your
                             # expectations, dispatch a background agent in an
                             # isolated worktree (branch chaosinthecrd/<slug>,
                             # slugified from the issue title)
take corp#45571 --provider codex   # default: claude (or set TAKE_PROVIDER)

chop --label Refined --limit 5     # fan out investigation agents over board
                                   # issues (shows selection, confirms first;
                                   # skips issues that already have an agent)

taken                        # list issue agents and their status
```

Agents get the full issue + comments (written to `~/.paseo-context-*.json` on
the VM), your notes, and a standing brief: investigate, write findings to
NOTES.md in the worktree, only implement if confident, commit to the branch,
never push. Pick up results with `paseo attach <id>` / the app, or fetch the
branch from the VM's repo.

`chop` deliberately defaults to investigation-only prompts and a small
`--limit` — the bottleneck is your review time, not compute.

`take`, `pocit`, and `reviewit` create the paseo workspace explicitly
(`paseo workspace create --title ...` + `paseo run --workspace ...`), so
the workspace shows a short human title in the app ("authkey reissuance")
instead of a branch name. The default title is derived from the issue
title / slug / review ref; override with `--ws-title <title>` on any of
the three. `reviewit` runs in a local (non-worktree) workspace on the
repo checkout, as before — the title just separates it in the app.

Two more dispatchers with the same shape:

```bash
pocit --file spec.md --project my-new-thing   # fresh git repo at ~/Git/my-new-thing
pocit --file spec.docx --repo corp            # worktree of an existing repo
                                              # (docx/rtf converted via textutil)

reviewit corp#12345                           # review a PR (gh pr view/diff on VM)
reviewit abc1234 --repo corp                  # review a commit in ~/Git/corp
reviewit chaosinthecrd/foo --repo tailscale   # review a VM-local branch (diff vs
                                              # --base, default origin/main) —
                                              # e.g. another agent's unpushed work
```

`take`, `pocit`, and `reviewit` all accept `--share`: pick Mac-side kube
contexts via kubeshare first, and the agent's brief tells it the clusters
were shared specifically for the task and it is expected to verify against
them (not just reason from code).

`pocit` agents scaffold, build, run, and iterate until the POC demonstrably
works (README + NOTES.md, committed). `reviewit` agents produce a
severity-ordered review in `~/reviews/<ref>.md` on the VM and leave the
checkout clean. All dispatch prompts instruct agents to work autonomously —
record assumptions instead of stopping to ask questions — and the VM's
`.claude_context.md` carries the `~/Git/<repo>` map so agents never stall on
"where is the code".

Agents writing or reviewing Go in tailscale k8s code follow
`~/.claude_k8s_style.md` on the VM (source: private-dots
`vm-files/claude_k8s_style.md`) — a style guide distilled from the
maintainers' git history and real PR review comments, so agent code reads
like the team wrote it. take/reviewit briefs point at it explicitly.

## Verification: docker, kind, shared clusters

The VM runs a docker daemon (bootstrap installs docker.io; user is in the
docker group), so agents can `kind create cluster` for e2e verification —
plus kubectl/k9s/helm etc. from `pkgs/kube.nix`.

For a real cluster only your Mac can reach (GKE behind auth, etc.):

```bash
# Mac:
kubectl proxy &     # 127.0.0.1:8001, injects your credentials
vmshare 8001
# VM/agent:
kubectl --kubeconfig ~/.kube/shared-cluster.yaml get pods
```

`~/.kube/shared-cluster.yaml` is shipped by the nix config and points at
`127.0.0.1:8001` — no credentials ever live on the VM.

## Private repos and GitHub data on the VM

- **Cloning:** `git clone https://github.com/tailscale/<repo>` transparently
  rewrites to `git://rogitproxy/tailscale/<repo>` (read-only proxy, no
  credentials). `curl http://rogitproxy/` lists accessible repos.
- **GitHub queries:** `gh` in `~/.local/bin` is maintner's read-only drop-in
  (issues, PRs, search, diffs) backed by `http://maintner.corp.ts.net` — no
  GitHub auth needed. `mn` offers the same data as a query CLI (needs a local
  `mnapid` for fast repeated queries; not set up by default).
