---
name: nixos-system-update-age
description: Use when asked how long ago the main NixOS system (not individual flakes) was last updated — determining the age of the root nixpkgs input in this flake.
---

# Determining When the Main System Was Last Updated

## Core principle

The system is built from the **root** `nixpkgs` input (`flake.nix`:
`mkSystem` → `inputs.nixpkgs.lib.nixosSystem`, tracks `nixos-unstable`).
Its age = the `lastModified` of the node the root input resolves to in
`flake.lock`.

## The trap (do NOT fall for it)

The node **literally named `nixpkgs`** in `flake.lock` is usually a *transitive*
copy pulled in by some other flake — it can be pinned a year back and is **not**
the system input. The real system input resolves through
`.nodes[.root].inputs.nixpkgs`, which points to something like `nixpkgs_9`.
Reading the wrongly-named node gives a wildly wrong answer.

## Command (run this, don't guess)

Resolve the real system nixpkgs and its date:

```bash
jq -r '.nodes[.root].inputs.nixpkgs as $n | .nodes[$n].locked
  | "node=\($n)  rev=\(.rev[0:10])  date=\(.lastModified|todate)"' flake.lock
```

`date` = the `nixos-unstable` commit date the system is pinned to ≈ when the
system was last updated.

Find when it was actually bumped in *this* repo's git history:

```bash
rev=$(jq -r '.nodes[.nodes[.root].inputs.nixpkgs].locked.rev' flake.lock)
git log -1 --format='%ci %h %s' -S "$rev" -- flake.lock
```

## Notes

- To update only the system input: `nix flake update nixpkgs`.
- `nixpkgs_N`, `home-manager_N`, etc. are transitive copies from other flakes —
  ignore them when the question is about the main system.
