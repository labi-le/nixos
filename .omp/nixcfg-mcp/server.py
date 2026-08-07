from config import INSTRUCTIONS, LATEST_PROTOCOL, PROTOCOLS, SERVER_INFO
from protocol import CANCELLED, ToolError, fail, reply
from registry import PUBLIC_TOOLS, TOOL_INDEX


def call_tool(params, request_id):
    if not isinstance(params, dict):
        fail(request_id, -32602, "params must be an object")
        return
    name = params.get("name")
    tool = TOOL_INDEX.get(name)
    if tool is None:
        fail(request_id, -32602, f"Unknown tool: {name}")
        return
    arguments = params.get("arguments") or {}
    if not isinstance(arguments, dict):
        fail(request_id, -32602, "arguments must be an object")
        return
    missing = [
        key for key in tool["inputSchema"].get("required", []) if arguments.get(key) in (None, "")
    ]
    if missing:
        fail(request_id, -32602, f"Missing required argument(s): {', '.join(missing)}")
        return
    meta = params.get("_meta")
    token = meta.get("progressToken") if isinstance(meta, dict) else None
    try:
        text, is_error = tool["handler"](arguments, request_id, token)
    except ToolError as error:
        text, is_error = str(error), True
    if str(request_id) in CANCELLED:
        return
    result = {"content": [{"type": "text", "text": text}]}
    if is_error:
        result["isError"] = True
    reply(request_id, result)


def handle(message):
    request_id = message.get("id")
    try:
        dispatch(message, request_id)
    except Exception as error:
        if request_id is not None:
            fail(request_id, -32603, f"{type(error).__name__}: {error}")
    finally:
        if request_id is not None:
            CANCELLED.discard(str(request_id))


def dispatch(message, request_id):
    method = message.get("method")
    params = message.get("params")
    if not isinstance(params, dict):
        params = {}
    if request_id is None:
        if method == "notifications/cancelled":
            cancelled = params.get("requestId")
            if cancelled is not None:
                CANCELLED.add(str(cancelled))
        return
    if method == "initialize":
        requested = params.get("protocolVersion")
        reply(
            request_id,
            {
                "protocolVersion": requested if requested in PROTOCOLS else LATEST_PROTOCOL,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": SERVER_INFO,
                "instructions": INSTRUCTIONS,
            },
        )
        return
    if method == "ping":
        reply(request_id, {})
        return
    if method == "tools/list":
        reply(request_id, {"tools": PUBLIC_TOOLS})
        return
    if method == "tools/call":
        call_tool(params, request_id)
        return
    fail(request_id, -32601, f"Method not found: {method}")
