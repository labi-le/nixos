import os
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROUTES = REPO / "docs" / "routes.md"
OMP_RULES = REPO / "home-manager" / "modules" / "omp"
LOCK = REPO / "flake.lock"
SECRETS_RULES = REPO / "secrets.nix"
SECRETS_DIR = REPO / "secrets"
AGE = "/run/current-system/sw/bin/age"
HOST_KEY_PUB = Path("/etc/ssh/ssh_host_ed25519_key.pub")
SUDO_PANE = os.environ.get("NIX_CONTROL_SUDO_PANE") or "nix-control"
HOSTS = ("pc", "fx516", "notebook", "server")
NIXOS_REBUILD = "/run/current-system/sw/bin/nixos-rebuild"
NIX_COLLECT_GARBAGE = "/run/current-system/sw/bin/nix-collect-garbage"
SYSTEM_PROFILES = Path("/nix/var/nix/profiles")
PROTOCOLS = ("2025-11-25", "2025-06-18", "2025-03-26", "2024-11-05")
LATEST_PROTOCOL = "2025-06-18"
SERVER_INFO = {"name": "nix-control", "title": "NixOS config operations", "version": "1.0.0"}
INSTRUCTIONS = (
    "Maintenance tools for the NixOS flake at "
    f"{REPO}. Rebuild, verify, roll back and route module edits. "
    "Use the `nixos` MCP server for package/option documentation instead."
)
STATE = Path(os.environ.get("XDG_STATE_HOME") or Path.home() / ".local" / "state") / "nix-control-mcp"
JOBS = STATE / "jobs"
MAX_TEXT = 20000
SHORT_TIMEOUT = 180
OWNER = Path.home().name
MAX_JOBS = 40
LOG_TAIL_BYTES = 256 * 1024
STOP_WORDS = frozenset(
    "the and for with from into that this how where add use set new when only "
    "change edit configure enable disable make host hosts file files module modules".split()
)
PATH_CELL_RE = re.compile(r"`([^`]+)`")
PATH_SHAPE_RE = re.compile(r"^[\w./@<>*+-]+\.(nix|ya?ml|age|json|jar|lock|patch|py|md)$")
DELIMITER_RE = re.compile(r"^\|[\s\-:|]+\|$")
DIRTY_WARNING_RE = re.compile(r"Git tree '.*' is dirty")
DRV_FAIL_RE = re.compile(r"builder for '(/nix/store/\S+\.drv)' failed|error: build of '(\S+)' failed")
FREED_RE = re.compile(r"(\d+) store paths deleted, (.+) freed")
WOULD_DELETE_RE = re.compile(r"(\d+) store paths would be deleted")
FRONTMATTER_KEY_RE = re.compile(r"^([\w-]+):\s*(.*)$")
FRONTMATTER_ITEM_RE = re.compile(r"^\s*-\s+(.*)$")
REGEX_META_RE = re.compile(r"[\\\[\](){}|+?^$]")
CONDITION_KEYS = ("condition", "ttsr_trigger", "ttsrTrigger")
DEDUP_THRESHOLD = 60
TRIVIAL_LINE = 12
MISSING_ATTR_RE = re.compile(r"attribute '[^']+' missing|does not provide attribute")
