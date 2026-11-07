import sys

from litellm.llms.chatgpt.authenticator import Authenticator
from litellm.llms.chatgpt.common_utils import GetAccessTokenError

RELOGIN_HINT = "systemctl start litellm-chatgpt-login"


def install_chatgpt_guard():
    def get_access_token(self):
        auth_data = self._read_auth_file()
        access_token = (auth_data or {}).get("access_token")
        if access_token and not self._is_token_expired(auth_data, access_token):
            return access_token
        raise GetAccessTokenError(
            message=(
                "stored ChatGPT access token is not usable and the request path "
                f"never refreshes or logs in; run `{RELOGIN_HINT}`"
            ),
            status_code=401,
        )

    Authenticator.get_access_token = get_access_token
    print(f"chatgpt guard: request-path token refresh disabled, login via {RELOGIN_HINT}", file=sys.stderr)
