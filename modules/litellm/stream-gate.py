import sys

from litellm import Router
from litellm.passthrough import timeout_utils

_original_get_stream_timeout = Router._get_stream_timeout
_original_resolve_passthrough_timeout = timeout_utils.resolve_llm_passthrough_timeout

POOL_SESSION_HEADER = "x-opencode-session"
GATE_FLOOR_SECONDS = 15.0
GATE_CEILING_SECONDS = 120.0
GATE_SECONDS_PER_1K_TOKENS = 0.3
CHARS_PER_TOKEN = 4


def _payload_chars(value):
    if isinstance(value, str):
        return 0 if value.startswith("data:") else len(value)
    if isinstance(value, dict):
        return sum(_payload_chars(item) for item in value.values())
    if isinstance(value, (list, tuple)):
        return sum(_payload_chars(item) for item in value)
    return 0


def _request_chars(request):
    payload = request.get("messages")
    if payload is None:
        payload = request.get("input")
    return _payload_chars(payload)


def first_byte_gate(request):
    tokens = _request_chars(request) / CHARS_PER_TOKEN
    gate = GATE_FLOOR_SECONDS + tokens / 1000.0 * GATE_SECONDS_PER_1K_TOKENS
    return min(GATE_CEILING_SECONDS, gate)


def _is_pool_deployment(params):
    headers = (params or {}).get("extra_headers") or {}
    return POOL_SESSION_HEADER in headers


def _caps_applied(request, params):
    if request.get("stream_timeout") is not None:
        return False
    return _is_pool_deployment(params)


def _capped(resolved, request):
    gate = first_byte_gate(request)
    try:
        ceiling = float(resolved)
    except (TypeError, ValueError):
        return gate
    return min(ceiling, gate)


def _patched_get_stream_timeout(self, kwargs, data):
    resolved = _original_get_stream_timeout(self, kwargs, data)
    if not _caps_applied(kwargs, data):
        return resolved
    return _capped(resolved, kwargs)


def _patched_resolve_passthrough_timeout(
    kwargs=None,
    litellm_params=None,
    router_timeout=None,
    router_stream_timeout=None,
):
    resolved = _original_resolve_passthrough_timeout(
        kwargs=kwargs,
        litellm_params=litellm_params,
        router_timeout=router_timeout,
        router_stream_timeout=router_stream_timeout,
    )
    request = kwargs if kwargs is not None else {}
    if not request.get("stream") or not _caps_applied(request, litellm_params):
        return resolved
    return _capped(resolved, request)


def install_stream_gate():
    Router._get_stream_timeout = _patched_get_stream_timeout
    timeout_utils.resolve_llm_passthrough_timeout = _patched_resolve_passthrough_timeout
    print(
        f"stream gate: pool streams abandon a silent upstream after "
        f"{GATE_FLOOR_SECONDS:g}s + {GATE_SECONDS_PER_1K_TOKENS:g}s per 1k prompt tokens, "
        f"ceiling {GATE_CEILING_SECONDS:g}s",
        file=sys.stderr,
    )
