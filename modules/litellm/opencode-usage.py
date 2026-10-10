import asyncio
import hashlib
import os
import time

import httpx

KEY_ENV_PREFIX = "LITELLM_OPENCODE_GO_KEY_"
MASTER_KEY_ENV = "LITELLM_MASTER_KEY"
METERED_KEY = "opencode_usage_metered"
USAGE_URL = os.environ.get("OPENCODE_USAGE_URL", "https://opencode.ai/zen/go/v1/usage")
SYNC_INTERVAL_SECONDS = int(os.environ.get("OPENCODE_USAGE_SYNC_SECONDS", "120"))
COOLDOWN_SECONDS = int(os.environ.get("OPENCODE_USAGE_COOLDOWN_SECONDS", "600"))
LIMIT_PERCENT = float(os.environ.get("OPENCODE_USAGE_LIMIT_PERCENT", "95"))
USER_AGENT = os.environ.get("OPENCODE_USAGE_USER_AGENT", "jcode/0.89.3")
SESSION = "litellm-usage-sync"
WINDOWS = ("rolling", "weekly", "monthly")

_snapshot = None
_task = None


def pool_env_keys():
    return {
        name: value
        for name, value in os.environ.items()
        if name.startswith(KEY_ENV_PREFIX) and value
    }


def resolve_api_key(configured):
    if configured.startswith("os.environ/"):
        return os.environ.get(configured.split("/", 1)[1], "")
    return configured


def exhausted_window(usage):
    for window in WINDOWS:
        data = usage.get(window) or {}
        if data.get("status") == "rate-limited":
            return window
        percent = data.get("percent")
        if isinstance(percent, (int, float)) and not isinstance(percent, bool):
            if percent >= LIMIT_PERCENT:
                return window
    return None


async def fetch_usage(client, key):
    response = await client.get(
        USAGE_URL,
        headers={
            "Authorization": f"Bearer {key}",
            "User-Agent": USER_AGENT,
            "x-opencode-session": SESSION,
        },
    )
    response.raise_for_status()
    return response.json().get("usage") or {}


def model_ids_by_key():
    from litellm.proxy.proxy_server import llm_router

    if llm_router is None:
        return {}
    mapping = {}
    for deployment in llm_router.model_list:
        params = deployment.get("litellm_params") or {}
        info = deployment.get("model_info") or {}
        model_id = info.get("id")
        api_key = resolve_api_key(str(params.get("api_key") or ""))
        if not (api_key and model_id):
            continue
        if info.get(METERED_KEY) is False:
            continue
        mapping.setdefault(api_key, []).append(model_id)
    return mapping


def aggregate_window(window, accounts):
    percents = [
        account["windows"][window]["percent"]
        for account in accounts
        if isinstance((account["windows"][window] or {}).get("percent"), (int, float))
    ]
    limited = [account for account in accounts if account["limited"] == window]
    resets = [
        account["windows"][window]["resetsAt"]
        for account in accounts
        if account["windows"][window].get("resetsAt")
    ]
    return {
        "percent": round(sum(percents) / len(percents)) if percents else 0,
        "status": "rate-limited" if len(limited) == len(accounts) else "ok",
        "resetsAt": min(resets) if limited and resets else None,
    }


def build_snapshot(accounts):
    return {
        "provider": "opencode-go-pool",
        "plan": "OpenCode Go",
        "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "usage": {window: aggregate_window(window, accounts) for window in WINDOWS},
    }


def key_usage(key_info):
    return {
        "alias": key_info.get("key_alias"),
        "spend_usd": key_info.get("spend"),
        "max_budget_usd": key_info.get("max_budget"),
        "expires_at": key_info.get("expires"),
    }


def session_counters():
    try:
        from opencode_session import counters

        return dict(counters)
    except Exception:
        return {}


def key_info_for(token):
    if not token:
        return {}
    try:
        response = httpx.get(
            "http://127.0.0.1:4000/key/info",
            params={"key": token},
            headers={"Authorization": f"Bearer {os.environ.get(MASTER_KEY_ENV, '')}"},
            timeout=5,
        )
        if response.status_code == 200:
            return response.json() or {}
    except Exception:
        return {}
    return {}


def authorize(authorization):
    token = authorization.split(" ", 1)[-1].strip() if authorization else ""
    master = os.environ.get(MASTER_KEY_ENV, "")
    if not token:
        raise ValueError("missing bearer token")
    if master and token == master:
        return {}
    info = key_info_for(hashlib.sha256(token.encode()).hexdigest())
    if not info:
        raise ValueError("invalid key")
    return info


def install_usage_route():
    from fastapi import Request
    from fastapi.responses import JSONResponse
    from litellm.proxy.proxy_server import app

    async def usage(request: Request):
        try:
            info = authorize(request.headers.get("authorization", ""))
        except ValueError as error:
            return JSONResponse(status_code=401, content={"detail": str(error)})
        if _snapshot is None:
            return JSONResponse(
                status_code=503,
                content={"detail": "usage snapshot not ready"},
                headers={"Retry-After": "30"},
            )
        body = dict(_snapshot)
        body["key"] = key_usage(info)
        body["sessions"] = session_counters()
        return JSONResponse(content=body)

    app.add_api_route("/v1/usage", usage, methods=["GET"])
    ensure_task()


def ensure_task():
    global _task
    if _task is None or _task.done():
        _task = asyncio.create_task(_sync_forever())


async def _sync_forever():
    while True:
        try:
            await sync_once()
        except Exception:
            pass
        await asyncio.sleep(SYNC_INTERVAL_SECONDS)


async def sync_once():
    global _snapshot
    from litellm.proxy.proxy_server import llm_router

    keys = pool_env_keys()
    if llm_router is None or not keys:
        return
    model_ids = model_ids_by_key()
    if not model_ids:
        return
    accounts = []
    async with httpx.AsyncClient(timeout=10) as client:
        for key in keys.values():
            key_model_ids = model_ids.get(key) or []
            if not key_model_ids:
                continue
            try:
                usage = await fetch_usage(client, key)
            except Exception:
                continue
            limited = exhausted_window(usage)
            if limited is not None:
                for model_id in key_model_ids:
                    llm_router.cooldown_cache.add_deployment_to_cooldown(
                        model_id=model_id,
                        original_exception=Exception(
                            f"opencode usage window {limited} at limit"
                        ),
                        exception_status=429,
                        cooldown_time=COOLDOWN_SECONDS,
                    )
            windows = {window: usage.get(window) or {} for window in WINDOWS}
            accounts.append({"limited": limited, "windows": windows})
    if accounts:
        _snapshot = build_snapshot(accounts)
