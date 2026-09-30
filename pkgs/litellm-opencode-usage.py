import asyncio
import os

import httpx
from litellm.integrations.custom_logger import CustomLogger

KEY_ENV_PREFIX = "LITELLM_OPENCODE_GO_KEY_"
USAGE_URL = os.environ.get("OPENCODE_USAGE_URL", "https://opencode.ai/zen/go/v1/usage")
SYNC_INTERVAL_SECONDS = int(os.environ.get("OPENCODE_USAGE_SYNC_SECONDS", "120"))
COOLDOWN_SECONDS = int(os.environ.get("OPENCODE_USAGE_COOLDOWN_SECONDS", "600"))
LIMIT_PERCENT = float(os.environ.get("OPENCODE_USAGE_LIMIT_PERCENT", "95"))
USER_AGENT = os.environ.get("OPENCODE_USAGE_USER_AGENT", "jcode/0.89.3")
SESSION = "litellm-usage-sync"
WINDOWS = ("rolling", "weekly", "monthly")


def pool_env_keys() -> dict[str, str]:
    return {
        name: value
        for name, value in os.environ.items()
        if name.startswith(KEY_ENV_PREFIX) and value
    }


def resolve_api_key(configured: str) -> str:
    if configured.startswith("os.environ/"):
        return os.environ.get(configured.split("/", 1)[1], "")
    return configured


def exhausted_window(usage: dict) -> str | None:
    for window in WINDOWS:
        data = usage.get(window) or {}
        if data.get("status") == "rate-limited":
            return window
        percent = data.get("percent")
        if isinstance(percent, (int, float)) and not isinstance(percent, bool):
            if percent >= LIMIT_PERCENT:
                return window
    return None


async def fetch_usage(client: httpx.AsyncClient, key: str) -> dict:
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


class OpencodeGoUsageSync(CustomLogger):
    def __init__(self):
        super().__init__()
        self._task: asyncio.Task | None = None

    async def async_log_success_event(self, kwargs, response_obj, start_time, end_time):
        await self._ensure_task()

    async def async_log_failure_event(self, kwargs, response_obj, start_time, end_time):
        await self._ensure_task()

    async def _ensure_task(self):
        if self._task is None or self._task.done():
            self._task = asyncio.create_task(self._sync_forever())

    async def _sync_forever(self):
        while True:
            try:
                await self._sync_once()
            except Exception:
                pass
            await asyncio.sleep(SYNC_INTERVAL_SECONDS)

    async def _sync_once(self):
        from litellm.proxy.proxy_server import llm_router

        if llm_router is None:
            return
        keys = pool_env_keys()
        if not keys:
            return
        model_ids = {}
        for deployment in llm_router.model_list:
            params = deployment.get("litellm_params") or {}
            model_id = (deployment.get("model_info") or {}).get("id")
            api_key = resolve_api_key(str(params.get("api_key") or ""))
            if api_key and model_id:
                model_ids[api_key] = model_id
        if not model_ids:
            return
        async with httpx.AsyncClient(timeout=10) as client:
            for key in keys.values():
                model_id = model_ids.get(key)
                if model_id is None:
                    continue
                try:
                    usage = await fetch_usage(client, key)
                except Exception:
                    continue
                window = exhausted_window(usage)
                if window is None:
                    continue
                llm_router.cooldown_cache.add_deployment_to_cooldown(
                    model_id=model_id,
                    original_exception=Exception(
                        f"opencode usage window {window} at limit"
                    ),
                    exception_status=429,
                    cooldown_time=COOLDOWN_SECONDS,
                )


opencode_go_usage_sync = OpencodeGoUsageSync()
