"""byesu upstream with a content-filter retry.

Google's safety filter intermittently rejects benign prompts, and the same
request usually passes on the next attempt. A response that stops on
`finish_reason=content_filter` before emitting any content is retried here,
inside the provider, so every client of the gateway inherits the behaviour.
Once a chunk with real content has been yielded the stream is passed through
unchanged: restarting it would duplicate tokens.
"""

import os
import time

import litellm
from litellm.llms.custom_llm import CustomLLM

ATTEMPTS = max(1, int(os.environ.get("LITELLM_CONTENT_FILTER_RETRIES", "4")))
BACKOFF_SECONDS = float(os.environ.get("LITELLM_CONTENT_FILTER_BACKOFF", "1.0"))
PROVIDER = "byesu"


def _params(model, messages, api_base, api_key, optional_params, kwargs):
    upstream = model.split("/", 1)[1] if "/" in model else model
    params = dict(optional_params or {})
    for name in ("stream", "stream_options"):
        params.pop(name, None)
    params.update(
        {
            "model": f"openai/{upstream}",
            "messages": messages,
            "api_base": api_base,
            "api_key": api_key,
        }
    )
    params.update(
        {
            key: value
            for key, value in (kwargs or {}).items()
            if key in {"timeout", "temperature", "max_tokens", "top_p", "stop", "tools", "tool_choice", "response_format", "user", "seed", "n"}
        }
    )
    return params


def _blocked(response):
    for choice in getattr(response, "choices", None) or []:
        if getattr(choice, "finish_reason", None) == "content_filter":
            return True
    return False


def _chunk_blocked(chunk):
    for choice in getattr(chunk, "choices", None) or []:
        if getattr(choice, "finish_reason", None) == "content_filter":
            delta = getattr(choice, "delta", None)
            content = getattr(delta, "content", None) if delta is not None else None
            return content in (None, ""), content not in (None, "")
    return False, False


class ByesuLLM(CustomLLM):
    def completion(self, model, messages, api_base=None, api_key=None, optional_params=None, **kwargs):
        response = None
        for attempt in range(ATTEMPTS):
            response = litellm.completion(**_params(model, messages, api_base, api_key, optional_params, kwargs))
            if not _blocked(response):
                return response
            time.sleep(BACKOFF_SECONDS * (attempt + 1))
        return response

    async def acompletion(self, model, messages, api_base=None, api_key=None, optional_params=None, **kwargs):
        response = None
        for attempt in range(ATTEMPTS):
            response = await litellm.acompletion(
                **_params(model, messages, api_base, api_key, optional_params, kwargs)
            )
            if not _blocked(response):
                return response
            time.sleep(BACKOFF_SECONDS * (attempt + 1))
        return response

    def streaming(self, model, messages, api_base=None, api_key=None, optional_params=None, **kwargs):
        for attempt in range(ATTEMPTS):
            stream = litellm.completion(
                stream=True,
                **_params(model, messages, api_base, api_key, optional_params, kwargs),
            )
            emitted = False
            for chunk in stream:
                blocked, has_content = _chunk_blocked(chunk)
                if blocked and not emitted:
                    break
                emitted = emitted or has_content
                yield chunk
            else:
                return
            time.sleep(BACKOFF_SECONDS * (attempt + 1))

    async def astreaming(self, model, messages, api_base=None, api_key=None, optional_params=None, **kwargs):
        for attempt in range(ATTEMPTS):
            stream = await litellm.acompletion(
                stream=True,
                **_params(model, messages, api_base, api_key, optional_params, kwargs),
            )
            emitted = False
            async for chunk in stream:
                blocked, has_content = _chunk_blocked(chunk)
                if blocked and not emitted:
                    break
                emitted = emitted or has_content
                yield chunk
            else:
                return
            time.sleep(BACKOFF_SECONDS * (attempt + 1))


def install_byesu_provider():
    litellm.custom_provider_map.append({"provider": PROVIDER, "custom_handler": ByesuLLM()})
