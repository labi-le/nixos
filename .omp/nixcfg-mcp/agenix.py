import json
import os
import threading
from pathlib import Path

from config import AGE, HOST_KEY_PUB, REPO, SECRETS_DIR, SECRETS_RULES
from pane import run_in_pane
from protocol import ToolError
from shell import nix_noise, run_split
from text import clamp, envelope, tail


def secret_rules():
    code, out, err = run_split(
        ["nix", "eval", "--file", str(SECRETS_RULES), "--json"], timeout=300
    )
    if code != 0:
        raise ToolError(f"cannot evaluate secrets.nix:\n{tail(nix_noise(err), 10)}")
    try:
        rules = json.loads(out)
    except ValueError:
        raise ToolError("secrets.nix did not evaluate to JSON data")
    return rules


def key_material(pubkey):
    parts = pubkey.split()
    return parts[1] if len(parts) > 1 else pubkey


def local_identities():
    found = []
    if HOST_KEY_PUB.exists():
        try:
            found.append(
                {
                    "identity": "/etc/ssh/ssh_host_ed25519_key",
                    "material": key_material(HOST_KEY_PUB.read_text().strip()),
                    "needs_root": True,
                }
            )
        except OSError:
            pass
    for pub in sorted((Path.home() / ".ssh").glob("*.pub")):
        private = pub.with_suffix("")
        if not private.exists():
            continue
        try:
            found.append(
                {
                    "identity": str(private),
                    "material": key_material(pub.read_text().strip()),
                    "needs_root": False,
                }
            )
        except OSError:
            continue
    return found


def recipient_label(pubkey):
    parts = pubkey.split()
    return parts[2] if len(parts) > 2 else key_material(pubkey)[:12]


def tool_secret_list(args, request_id, token):
    rules = secret_rules()
    identities = local_identities()
    by_material = {entry["material"]: entry for entry in identities}
    secrets = []
    for path in sorted(rules):
        spec = rules[path] or {}
        recipients = spec.get("publicKeys") or []
        target = REPO / path
        usable = [
            by_material[key_material(pubkey)]
            for pubkey in recipients
            if key_material(pubkey) in by_material
        ]
        entry = {
            "path": path,
            "recipients": [recipient_label(pubkey) for pubkey in recipients],
            "exists": target.exists(),
            "armor": bool(spec.get("armor")),
        }
        if usable:
            entry["decrypt_here"] = {
                "identity": usable[0]["identity"],
                "needs_root": usable[0]["needs_root"],
            }
        else:
            entry["decrypt_here"] = None
        secrets.append(entry)
    known = set(rules)
    orphans = sorted(
        str(found.relative_to(REPO))
        for found in SECRETS_DIR.rglob("*.age")
        if str(found.relative_to(REPO)) not in known
    )
    header = {
        "rules_file": "secrets.nix",
        "count": len(secrets),
        "identities_readable_without_root": [
            entry["identity"] for entry in identities if not entry["needs_root"]
        ],
        "secrets": secrets,
    }
    if orphans:
        header["age_files_without_a_rule"] = orphans
    missing = [entry["path"] for entry in secrets if not entry["exists"]]
    if missing:
        header["rules_without_a_file"] = missing
    header["note"] = (
        "writing a secret needs only the recipients' public keys; reading or editing one "
        "needs a private key listed in recipients, so decrypt_here: null means that secret "
        "cannot be opened on this host at all"
    )
    return envelope(header), False


def pick_identity(recipients):
    by_material = {entry["material"]: entry for entry in local_identities()}
    usable = [
        by_material[key_material(pubkey)]
        for pubkey in recipients
        if key_material(pubkey) in by_material
    ]
    if not usable:
        return None
    usable.sort(key=lambda entry: entry["needs_root"])
    return usable[0]


def decrypt_secret(path, recipients):
    identity = pick_identity(recipients)
    if identity is None:
        raise ToolError(
            f"no private key on this host is a recipient of {path}; it cannot be decrypted here "
            "at any privilege level. Rekey it on a host that is a recipient, or add a local key "
            "to its publicKeys in secrets.nix"
        )
    argv = [AGE, "-d", "-i", identity["identity"], str(REPO / path)]
    if identity["needs_root"]:
        code, out, err = run_in_pane(["sudo", "-n"] + argv, timeout=120)
    else:
        code, out, err = run_split(argv, timeout=300, raw=True)
    if code != 0:
        raise ToolError(
            f"decrypt failed with {code} using {identity['identity']}:\n{tail(err, 6)}"
        )
    return out, identity


def tool_secret_read(args, request_id, token):
    path = (args.get("path") or "").strip()
    if not path:
        raise ToolError("path is required")
    rules = secret_rules()
    if path not in rules:
        raise ToolError(f"{path!r} has no rule in secrets.nix")
    if args.get("confirm") != "yes":
        raise ToolError(
            "reading a secret puts its plaintext into this session's transcript and session "
            "file on disk; pass confirm=\"yes\" if that is acceptable"
        )
    recipients = rules[path].get("publicKeys") or []
    plaintext, identity = decrypt_secret(path, recipients)
    header = {
        "path": path,
        "identity": identity["identity"],
        "needed_root": identity["needs_root"],
        "bytes": len(plaintext),
        "warning": "the plaintext below is now in the transcript",
    }
    return envelope(header, clamp(plaintext.decode("utf-8", "replace"))), False


def tool_secret_rekey(args, request_id, token):
    rules = secret_rules()
    wanted = args.get("paths") or []
    if isinstance(wanted, str):
        wanted = [wanted]
    targets = wanted or sorted(rules)
    unknown = [path for path in targets if path not in rules]
    if unknown:
        raise ToolError("no rule in secrets.nix for: " + ", ".join(unknown))
    done = []
    skipped = []
    for path in targets:
        target = REPO / path
        recipients = rules[path].get("publicKeys") or []
        if not target.exists():
            skipped.append({"path": path, "reason": "no .age file yet"})
            continue
        if pick_identity(recipients) is None:
            skipped.append({"path": path, "reason": "not decryptable on this host"})
            continue
        plaintext, identity = decrypt_secret(path, recipients)
        argv = [AGE]
        if rules[path].get("armor"):
            argv.append("--armor")
        for pubkey in recipients:
            argv += ["--recipient", pubkey]
        staged = target.with_name(f"{target.name}.{os.getpid()}.{threading.get_ident()}.new")
        argv += ["-o", str(staged)]
        installed = False
        try:
            code, out, err = run_split(argv, timeout=120, stdin_data=plaintext)
            if code != 0:
                raise ToolError(f"re-encrypting {path} failed with {code}:\n{tail(err, 6)}")
            written = staged.read_bytes()
            if not written.startswith((b"age-encryption.org/v1", b"-----BEGIN AGE ENCRYPTED FILE-----")):
                raise ToolError(f"re-encrypting {path} produced no age header; {path} left untouched")
            os.replace(staged, target)
            installed = True
        finally:
            if not installed:
                staged.unlink(missing_ok=True)
        done.append(
            {
                "path": path,
                "recipients": [recipient_label(pubkey) for pubkey in recipients],
                "identity": identity["identity"],
            }
        )
    header = {
        "rekeyed": done,
        "skipped": skipped,
        "note": "plaintext never enters the transcript; when the host key is needed it transits "
        "a 0700 tmpfs scratch dir purged on every exit path including SIGTERM. Run after "
        "changing publicKeys in secrets.nix",
    }
    return envelope(header), False


def tool_secret_write(args, request_id, token):
    path = (args.get("path") or "").strip()
    if not path:
        raise ToolError("path is required")
    rules = secret_rules()
    if path not in rules:
        raise ToolError(
            f"{path!r} has no rule in secrets.nix; add its publicKeys there first. "
            "Known: " + ", ".join(sorted(rules))
        )
    content = args.get("content")
    source = args.get("from_file")
    if (content is None) == (source is None):
        raise ToolError("pass exactly one of content or from_file")
    if source is not None:
        origin = Path(source)
        if not origin.is_absolute():
            raise ToolError("from_file must be an absolute path")
        try:
            origin = origin.resolve(strict=True)
        except OSError as error:
            raise ToolError(f"cannot read {source}: {error}")
        if origin == REPO or REPO in origin.parents:
            raise ToolError("from_file must live outside the repo so plaintext is never committed")
        try:
            plaintext = origin.read_bytes()
        except OSError as error:
            raise ToolError(f"cannot read {source}: {error}")
    else:
        if not isinstance(content, str):
            raise ToolError("content must be a string")
        plaintext = content.encode()
    if not plaintext:
        raise ToolError("refusing to write an empty secret")
    target = REPO / path
    if target.exists() and args.get("confirm") != "yes":
        raise ToolError(
            f"{path} already exists and its current value cannot be recovered from this host "
            "once overwritten; pass confirm=\"yes\""
        )
    spec = rules[path] or {}
    recipients = spec.get("publicKeys") or []
    if not recipients:
        raise ToolError(f"{path} has no publicKeys in secrets.nix")
    argv = [AGE]
    if spec.get("armor"):
        argv.append("--armor")
    for pubkey in recipients:
        argv += ["--recipient", pubkey]
    target.parent.mkdir(parents=True, exist_ok=True)
    staged = target.with_name(f"{target.name}.{os.getpid()}.{threading.get_ident()}.new")
    argv += ["-o", str(staged)]
    installed = False
    try:
        code, out, err = run_split(argv, timeout=120, stdin_data=plaintext)
        if code != 0:
            raise ToolError(f"age failed with {code}:\n{tail(nix_noise(err), 10)}")
        written = staged.read_bytes()
        if not written.startswith((b"age-encryption.org/v1", b"-----BEGIN AGE ENCRYPTED FILE-----")):
            raise ToolError("age produced no recognizable header; refusing to install the file")
        existed = target.exists()
        os.replace(staged, target)
        installed = True
    finally:
        if not installed:
            staged.unlink(missing_ok=True)
    header = {
        "path": path,
        "action": "replaced" if existed else "created",
        "recipients": [recipient_label(pubkey) for pubkey in recipients],
        "armor": bool(spec.get("armor")),
        "bytes": len(written),
        "source": "from_file" if source is not None else "content",
        "next": "git add " + path + " (a path flakeref ignores untracked files)",
    }
    if source is None:
        header["warning"] = (
            "the plaintext was passed as a tool argument, so it is in this session's transcript; "
            "use from_file with a path outside the repo to keep it out"
        )
    return envelope(header), False
