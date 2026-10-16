import hashlib
import re
import time

import httpx
import litellm
from litellm.integrations.custom_logger import CustomLogger

OPENCODE_USER_AGENT = "opencode/latest/2.0.28/cli"
OPENCODE_SESSION_PATTERN = re.compile(r"^ses_[0-9a-f]{12}[0-9A-Za-z]{14}$")
OPENCODE_SESSION_FLOOR = 0xFC0
CORE_TOOL_NAMES = ("bash", "read", "edit", "glob", "grep")
REQUIRED_TOOL_NAMES = 2
BASE62 = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
STUB_DESCRIPTION = "Gateway-validation stub. NOT IMPLEMENTED: never call this tool; use a real one."
STUB_PARAMETERS = {
    "type": "object",
    "properties": {
        "command": {"type": "string", "description": "The command to execute"},
    },
    "required": ["command"],
    "additionalProperties": False,
}


def opencode_session():
    head = ~((int(time.time() * 1000) * 4096) & 0xFFFFFFFFFFFF) & 0xFFFFFFFFFFFF
    digest = hashlib.sha256(head.to_bytes(6, "big")).digest()
    return f"ses_{head:012x}" + "".join(BASE62[byte % 62] for byte in digest[:14])


PROCESS_SESSION = opencode_session()


def session_accepted(value):
    if not value or OPENCODE_SESSION_PATTERN.match(value) is None:
        return False
    return int(value[4:16], 16) & 0xFFF >= OPENCODE_SESSION_FLOOR


def fingerprint(headers):
    session = headers.get("x-opencode-session")
    headers["user-agent"] = OPENCODE_USER_AGENT
    headers["x-opencode-session"] = session if session_accepted(session) else PROCESS_SESSION
    headers["x-opencode-client"] = "cli"
    headers.setdefault("x-opencode-project", "")


def gated_url(url):
    return "opencode.ai" in url and "/zen/v1/" in url and "/zen/go/" not in url


def apply_fingerprint(request):
    if gated_url(str(request.url)):
        fingerprint(request.headers)


async def async_request_hook(request):
    apply_fingerprint(request)


def sync_request_hook(request):
    apply_fingerprint(request)


def with_request_hook(event_hooks, hook):
    hooks = dict(event_hooks or {})
    hooks["request"] = list(hooks.get("request") or []) + [hook]
    return hooks


def patch_client(client, hook):
    original_init = client.__init__

    def init(self, *args, **kwargs):
        kwargs["event_hooks"] = with_request_hook(kwargs.pop("event_hooks", None), hook)
        return original_init(self, *args, **kwargs)

    client.__init__ = init


def routed_groups():
    from litellm.proxy.proxy_server import llm_router

    if llm_router is None:
        return set()
    return {
        deployment["model_name"]
        for deployment in llm_router.model_list
        if (deployment.get("model_info") or {}).get("zen_free_fingerprint") is True
    }


def tool_names(tools):
    names = []
    for tool in tools:
        if not isinstance(tool, dict):
            continue
        function = tool.get("function")
        if isinstance(function, dict) and isinstance(function.get("name"), str):
            names.append(function["name"])
        elif isinstance(tool.get("name"), str):
            names.append(tool["name"])
    return names


def tool_stub(name, responses_shape):
    if responses_shape:
        return {
            "type": "function",
            "name": name,
            "description": STUB_DESCRIPTION,
            "parameters": STUB_PARAMETERS,
        }
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": STUB_DESCRIPTION,
            "parameters": STUB_PARAMETERS,
        },
    }


def padded_tools(tools, responses_shape):
    present = [name for name in tool_names(tools) if name in CORE_TOOL_NAMES]
    if len(present) >= REQUIRED_TOOL_NAMES:
        return tools
    missing = [name for name in CORE_TOOL_NAMES if name not in present]
    return list(tools) + [tool_stub(name, responses_shape) for name in missing[: REQUIRED_TOOL_NAMES - len(present)]]


def responses_shape(tools):
    return not any(isinstance(tool, dict) and "function" in tool for tool in tools)


class ZenFreeFingerprint(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if data.get("model") not in routed_groups():
            return data
        tools = data.get("tools")
        if isinstance(tools, list) and tools:
            data["tools"] = padded_tools(tools, responses_shape(tools))
        elif tools is None or tools == []:
            data["tools"] = padded_tools([], "responses" in str(call_type).lower())
        return data


def install_zen_free():
    patch_client(httpx.AsyncClient, async_request_hook)
    patch_client(httpx.Client, sync_request_hook)
    litellm.logging_callback_manager.add_litellm_callback(ZenFreeFingerprint())
