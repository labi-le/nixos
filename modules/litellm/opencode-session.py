import litellm
from litellm.integrations.custom_logger import CustomLogger

SESSION_HEADER = "x-opencode-session"
MAX_SESSION_LENGTH = 200

counters = {"client": 0, "fallback": 0}


def client_session(data):
    headers = (data.get("proxy_server_request") or {}).get("headers") or {}
    for name, value in headers.items():
        if name.lower() == SESSION_HEADER:
            session = str(value).strip()[:MAX_SESSION_LENGTH]
            return session or None
    return None


class SessionForwarder(CustomLogger):
    async def async_pre_call_hook(self, user_api_key_dict, cache, data, call_type):
        if "completion" not in str(call_type):
            return data
        session = client_session(data)
        if session is None:
            counters["fallback"] += 1
            return data
        counters["client"] += 1
        data["headers"] = {SESSION_HEADER: session}
        return data


def install_session_forwarder():
    litellm.logging_callback_manager.add_litellm_callback(SessionForwarder())
