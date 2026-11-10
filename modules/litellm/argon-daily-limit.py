import json
import os
import sys
from datetime import datetime, timedelta, timezone

import litellm
from litellm.exceptions import RateLimitType
from litellm.integrations.custom_logger import CustomLogger
from litellm.proxy.common_utils.proxy_rate_limit_error import ProxyRateLimitError

MODEL = "gemini-4-argon"
STATE_DIR = "/var/lib/litellm-limits"
STATE_PATH = os.path.join(STATE_DIR, "argon-daily.json")
DEFAULT_LIMIT = 50
DEFAULT_EXEMPT = "labile,pr-reviewer,murmur-pr-reviewer,buer-agent"


def _utc_day():
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _seconds_until_utc_midnight():
    now = datetime.now(timezone.utc)
    tomorrow = (now + timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
    return max(1, int((tomorrow - now).total_seconds()))


def _limit():
    return int(os.environ.get("ARGON_DAILY_REQUEST_LIMIT", DEFAULT_LIMIT))


def _exempt_aliases():
    return {
        alias.strip()
        for alias in os.environ.get("ARGON_DAILY_REQUEST_LIMIT_EXEMPT", DEFAULT_EXEMPT).split(",")
        if alias.strip()
    }


class DailyRequestCounter:
    def __init__(self, path):
        self.path = path
        self.day = None
        self.counts = {}
        self.load()

    def load(self):
        try:
            with open(self.path, encoding="utf-8") as handle:
                state = json.load(handle)
        except (OSError, ValueError):
            return
        if not isinstance(state, dict):
            return
        day = state.get("day")
        counts = state.get("counts")
        self.day = day if isinstance(day, str) else None
        self.counts = (
            {str(key): value for key, value in counts.items() if isinstance(value, int) and not isinstance(value, bool)}
            if isinstance(counts, dict)
            else {}
        )

    def save(self):
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        temporary = f"{self.path}.tmp"
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump({"day": self.day, "counts": self.counts}, handle)
        os.replace(temporary, self.path)

    def used(self, key, day):
        if self.day != day:
            self.day = day
            self.counts = {}
        return self.counts.get(key, 0)

    def admit(self, key, day):
        if self.day != day:
            self.day = day
            self.counts = {}
        self.counts[key] = self.counts.get(key, 0) + 1
        self.save()
        return self.counts[key]


class ArgonDailyLimit(CustomLogger):
    def __init__(self):
        self.counter = DailyRequestCounter(STATE_PATH)
        self.limit = _limit()
        self.exempt = _exempt_aliases()

    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        requested = (data or {}).get("model")
        if not isinstance(requested, str) or requested.split("/")[-1] != MODEL:
            return data
        if user_api_key_dict.key_alias in self.exempt:
            return data
        if str(user_api_key_dict.user_role or "") in ("proxy_admin", "proxy_admin_viewer"):
            return data
        key = user_api_key_dict.token or user_api_key_dict.api_key
        if not key:
            return data
        day = _utc_day()
        used = self.counter.used(key, day)
        if used >= self.limit:
            retry_after = _seconds_until_utc_midnight()
            raise ProxyRateLimitError(
                detail={
                    "error": {
                        "message": (
                            f"{MODEL} accepts {self.limit} requests per key per UTC day; "
                            f"this key used {used}. The counter resets at 00:00 UTC."
                        ),
                        "type": "daily_request_limit",
                        "code": 429,
                        "model": MODEL,
                        "limit": self.limit,
                        "used": used,
                        "retry_after_seconds": retry_after,
                    }
                },
                headers={"retry-after": retry_after, "x-litellm-ratelimit-type": "daily-requests"},
                rate_limit_type=RateLimitType.REQUESTS,
                model=MODEL,
            )
        self.counter.admit(key, day)
        return data


def install_argon_daily_limit():
    limiter = ArgonDailyLimit()
    litellm.logging_callback_manager.add_litellm_callback(limiter)
    print(
        f"argon daily limit: {MODEL} {limiter.limit} requests per key per UTC day, "
        f"exempt aliases {sorted(limiter.exempt)}, state {STATE_PATH}",
        file=sys.stderr,
    )
