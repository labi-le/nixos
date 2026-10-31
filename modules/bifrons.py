#!/usr/bin/env python3
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.request
import uuid
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VIDEO_PATH = re.compile(r"^/yt/([A-Za-z0-9_-]{6,20})$")
YOUTUBE_URL = re.compile(
    r"https?://(?:www\.|m\.|music\.)?(?:youtube\.com/(?:watch\?[^\s]*v=|shorts/|live/)|youtu\.be/)"
    r"([A-Za-z0-9_-]{6,20})"
)
CHANNEL_URL = re.compile(
    r"https?://(?:www\.|m\.)?youtube\.com/"
    r"(?:@[A-Za-z0-9_.-]+|channel/[A-Za-z0-9_-]+|c/[A-Za-z0-9_.-]+|user/[A-Za-z0-9_.-]+)"
    r"(?:/(?:videos|shorts|streams))?"
)
PLAYLIST_URL = re.compile(
    r"https?://(?:www\.|m\.)?youtube\.com/playlist\?[^\s]*list=[A-Za-z0-9_-]+"
)
QUEUE_ACTIONS = {
    "prev": "player_queues/previous",
    "play_pause": "player_queues/play_pause",
    "next": "player_queues/next",
    "stop": "player_queues/stop",
    "pause": "player_queues/pause",
    "resume": "player_queues/resume",
}
QUEUE_TEXT = {
    "prev": "player_queues/previous",
    "next": "player_queues/next",
    "stop/play": "player_queues/play_pause",
}
VOLUME_TEXT = {
    "vol -": "players/cmd/volume_down",
    "vol +": "players/cmd/volume_up",
}
KEYBOARD = {
    "keyboard": [
        [{"text": "prev"}, {"text": "next"}, {"text": "stop/play"}],
        [{"text": "vol -"}, {"text": "vol +"}, {"text": "queue"}],
    ],
    "resize_keyboard": True,
    "is_persistent": True,
}
CACHE_TTL = 1800
CACHE = {}
QUEUE = {"id": None}
CHANNEL_FILL = {"generation": 0}
QUEUE_PANEL = {}


class MaError(RuntimeError):
    def __init__(self, status, message):
        super().__init__(message)
        self.status = status


def environment(name, default=None):
    value = os.environ.get(name, default)
    if value is None:
        sys.exit(f"bifrons: {name} is not set")
    return value


MA_URL = environment("MA_URL", "http://127.0.0.1:8095").rstrip("/")
MA_TOKEN = environment("MA_TOKEN")
BOT_TOKEN = environment("TELEGRAM_BOT_TOKEN")
BIND = environment("BIFRONS_BIND", "127.0.0.1:8096")
CHAT_IDS = {
    int(item) for item in environment("BIFRONS_CHAT_IDS", "395448554").split(",") if item.strip()
}
QUEUE_OVERRIDE = environment("BIFRONS_QUEUE", "").strip()
YTDLP = environment("YTDLP", "yt-dlp")


def resolver_base(bind):
    host, _, port = bind.rpartition(":")
    if not host or host in ("0.0.0.0", "::"):
        host = "127.0.0.1"
    return f"http://{host}:{port or '8096'}"


RESOLVER = resolver_base(BIND)


def log(message):
    print(message, flush=True)


def ma(command, **args):
    body = json.dumps(
        {"message_id": uuid.uuid4().hex, "command": command, "args": args or None}
    ).encode()
    request = urllib.request.Request(
        f"{MA_URL}/api",
        data=body,
        method="POST",
        headers={
            "Authorization": f"Bearer {MA_TOKEN}",
            "Content-Type": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = response.read()
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace").strip()
        raise MaError(error.code, detail or f"music assistant returned {error.code}") from None
    except urllib.error.URLError as error:
        raise RuntimeError(f"music assistant is unreachable: {error.reason}") from None
    return json.loads(payload) if payload else None


def queue_id():
    if QUEUE["id"]:
        return QUEUE["id"]
    if QUEUE_OVERRIDE:
        QUEUE["id"] = QUEUE_OVERRIDE
        return QUEUE["id"]
    for player in ma("players/all") or []:
        name = (player.get("name") or "").lower()
        if player.get("provider") == "snapcast" and "station" in name:
            QUEUE["id"] = player["player_id"]
            return QUEUE["id"]
    raise RuntimeError("станция не найдена в Music Assistant")


def forget_queue():
    QUEUE["id"] = None


def probe(video_id):
    cached = CACHE.get(video_id)
    if cached and cached["expires"] > time.time():
        return cached
    command = [YTDLP, "--no-playlist", "--no-warnings", "-J", f"https://www.youtube.com/watch?v={video_id}"]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise RuntimeError("yt-dlp не ответил за 120 секунд") from None
    if completed.returncode != 0:
        lines = [line for line in completed.stderr.splitlines() if line.strip()]
        raise RuntimeError(lines[-1].strip() if lines else "yt-dlp failed")
    info = json.loads(completed.stdout)
    formats = [
        item
        for item in info.get("formats") or []
        if item.get("url")
        and item.get("acodec") not in (None, "none")
        and item.get("vcodec") in (None, "none")
    ]
    formats.sort(key=lambda item: (item.get("ext") == "m4a", item.get("abr") or 0), reverse=True)
    url = formats[0]["url"] if formats else info.get("url")
    if not url:
        raise RuntimeError("yt-dlp не нашёл аудиопоток")
    entry = {
        "id": info.get("id") or video_id,
        "url": url,
        "title": info.get("title") or video_id,
        "expires": time.time() + CACHE_TTL,
    }
    CACHE[entry["id"]] = entry
    CACHE[video_id] = entry
    return entry


def channel_entries(url):
    if "/playlist" not in url:
        base = url.split("?", 1)[0].rstrip("/")
        if not re.search(r"/(?:videos|shorts|streams)$", base):
            url = f"{base}/videos"
    command = [YTDLP, "--flat-playlist", "--no-warnings", "-J", url]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, timeout=120)
    except subprocess.TimeoutExpired:
        raise RuntimeError("yt-dlp не ответил за 120 секунд") from None
    if completed.returncode != 0:
        lines = [line for line in completed.stderr.splitlines() if line.strip()]
        raise RuntimeError(lines[-1].strip() if lines else "yt-dlp failed")
    info = json.loads(completed.stdout)
    entries = []
    for item in info.get("entries") or []:
        video_id = item.get("id")
        if not video_id or item.get("live_status") in ("is_live", "is_upcoming"):
            continue
        entries.append({"id": video_id, "title": item.get("title") or video_id})
    if not entries:
        raise RuntimeError("на канале нет доступных видео")
    return info.get("title") or url, entries


class Resolver(BaseHTTPRequestHandler):
    server_version = "bifrons"

    def do_GET(self):
        self.serve(True)

    def do_HEAD(self):
        self.serve(False)

    def serve(self, with_body):
        match = VIDEO_PATH.match(self.path.split("?", 1)[0])
        if not match:
            self.answer(404, "not found", with_body)
            return
        video_id = match.group(1)
        try:
            target = probe(video_id)["url"]
        except Exception as error:
            log(f"resolve {video_id} failed: {error}")
            self.answer(502, str(error), with_body)
            return
        log(f"redirect {video_id}")
        self.send_response(302)
        self.send_header("Location", target)
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def answer(self, status, text, with_body):
        body = text.encode()
        self.send_response(status)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if with_body:
            self.wfile.write(body)

    def log_message(self, message, *args):
        log(f"resolver: {message % args}")


def serve_resolver():
    host, _, port = BIND.rpartition(":")
    server = ThreadingHTTPServer((host or "127.0.0.1", int(port or 8096)), Resolver)
    server.daemon_threads = True
    log(f"listening on {BIND}")
    server.serve_forever()


def tg(method, **params):
    body = json.dumps(params).encode()
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{BOT_TOKEN}/{method}",
        data=body,
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            payload = json.loads(response.read() or b"{}")
    except urllib.error.HTTPError as error:
        detail = error.read().decode(errors="replace").strip()
        raise RuntimeError(detail or f"telegram returned {error.code}") from None
    if not payload.get("ok"):
        raise RuntimeError(payload.get("description") or "telegram error")
    return payload.get("result")


def say(chat_id, text, reply_markup=None):
    params = {"chat_id": chat_id, "text": text, "disable_web_page_preview": True}
    if reply_markup:
        params["reply_markup"] = reply_markup
    return tg("sendMessage", **params)


def rewrite(chat_id, message_id, text):
    tg(
        "editMessageText",
        chat_id=chat_id,
        message_id=message_id,
        text=text,
        disable_web_page_preview=True,
    )


def queue_media(uri, option):
    try:
        ma("player_queues/play_media", queue_id=queue_id(), media=[uri], option=option)
    except MaError as error:
        if error.status != 404:
            raise
        forget_queue()
        ma("player_queues/play_media", queue_id=queue_id(), media=[uri], option=option)


def play_on_station(uri):
    queue_media(uri, "replace")


def enqueue(uri):
    queue_media(uri, "add")


def stop_fill():
    CHANNEL_FILL["generation"] += 1


def fill_channel(generation, uris):
    for uri in uris:
        if CHANNEL_FILL["generation"] != generation:
            return
        try:
            enqueue(uri)
        except Exception as error:
            log(f"enqueue {uri} failed: {error}")


def start_fill(uris):
    generation = CHANNEL_FILL["generation"]
    threading.Thread(target=fill_channel, args=(generation, uris), daemon=True).start()


def add_and_play(video_id):
    entry = probe(video_id)
    play_on_station(f"builtin://track/{RESOLVER}/yt/{entry['id']}")
    return entry["title"]


def handle_channel(chat_id, url):
    stop_fill()
    placeholder = say(chat_id, "⏳ Собираю видео…")
    message_id = placeholder["message_id"]
    try:
        title, entries = channel_entries(url)
        first = entries[0]
        play_on_station(f"builtin://track/{RESOLVER}/yt/{first['id']}")
        start_fill(
            [f"builtin://track/{RESOLVER}/yt/{item['id']}" for item in entries[1:]]
        )
        text = f"▶️ {first['title']}\nОчередь: {len(entries)} видео"
        if title and title != first["title"]:
            text += f"\n{title}"
        try:
            tg("deleteMessage", chat_id=chat_id, message_id=message_id)
        except Exception as error:
            log(f"delete placeholder failed: {error}")
        say(chat_id, text, reply_markup=KEYBOARD)
    except Exception as error:
        log(f"channel {url} failed: {error}")
        rewrite(chat_id, message_id, f"⚠️ {error}")


def show_queue(chat_id, message_id=None):
    try:
        queue = ma("player_queues/get", queue_id=queue_id()) or {}
        current = queue.get("current_index")
        offset = current + 1 if isinstance(current, int) else 0
        items = ma("player_queues/items", queue_id=queue_id(), limit=10, offset=offset) or []
        current_name = (queue.get("current_item") or {}).get("name")
        text = f"Очередь: {queue.get('items', 0)}"
        if current_name:
            text += f"\nСейчас: {current_name}"
        rows = [
            [
                {
                    "text": f"{offset + index + 1}. {item.get('name') or '?'}"[:64],
                    "callback_data": f"jump:{offset + index}",
                }
            ]
            for index, item in enumerate(items)
        ]
        keyboard = {"inline_keyboard": rows}
        if message_id:
            try:
                tg(
                    "editMessageText",
                    chat_id=chat_id,
                    message_id=message_id,
                    text=text,
                    disable_web_page_preview=True,
                    reply_markup=keyboard,
                )
                return
            except RuntimeError:
                pass
        sent = tg(
            "sendMessage",
            chat_id=chat_id,
            text=text,
            disable_web_page_preview=True,
            reply_markup=keyboard,
        )
        if isinstance(sent, dict):
            QUEUE_PANEL[chat_id] = sent.get("message_id")
    except Exception as error:
        log(f"queue panel failed: {error}")
        say(chat_id, f"⚠️ {error}")


def handle_play(chat_id, video_id, playlist):
    stop_fill()
    placeholder = say(chat_id, "⏳ Резолвлю ролик…")
    message_id = placeholder["message_id"]
    try:
        title = add_and_play(video_id)
        text = f"▶️ {title}\nИграет на станции"
        if playlist:
            text += "\nПлейлист: играю первый ролик."
        rewrite(chat_id, message_id, text)
    except Exception as error:
        log(f"play {video_id} failed: {error}")
        rewrite(chat_id, message_id, f"⚠️ {error}")


def handle_callback(callback):
    message = callback.get("message") or {}
    chat_id = (message.get("chat") or {}).get("id")
    if chat_id not in CHAT_IDS:
        return
    data = callback.get("data") or ""
    try:
        if data.startswith("jump:"):
            index = int(data.split(":", 1)[1])
            ma("player_queues/play_index", queue_id=queue_id(), index=index)
            tg("answerCallbackQuery", callback_query_id=callback["id"], text="ок")
            show_queue(chat_id, message.get("message_id"))
            return
        if data in QUEUE_ACTIONS:
            ma(QUEUE_ACTIONS[data], queue_id=queue_id())
        elif data == "vol_up":
            ma("players/cmd/volume_up", player_id=queue_id())
        elif data == "vol_down":
            ma("players/cmd/volume_down", player_id=queue_id())
        else:
            raise RuntimeError("неизвестная кнопка")
        tg("answerCallbackQuery", callback_query_id=callback["id"], text="ок")
    except Exception as error:
        log(f"callback {data} failed: {error}")
        tg("answerCallbackQuery", callback_query_id=callback["id"], text=f"⚠️ {error}"[:200])


def handle_message(message):
    chat_id = message["chat"]["id"]
    if chat_id not in CHAT_IDS:
        return
    text = (message.get("text") or "").strip()
    if not text:
        return
    if text == "queue":
        show_queue(chat_id, QUEUE_PANEL.get(chat_id))
        return
    try:
        if text in QUEUE_TEXT:
            ma(QUEUE_TEXT[text], queue_id=queue_id())
            return
        if text in VOLUME_TEXT:
            ma(VOLUME_TEXT[text], player_id=queue_id())
            return
    except Exception as error:
        log(f"button {text} failed: {error}")
        say(chat_id, f"⚠️ {error}")
        return
    channel = CHANNEL_URL.search(text) or PLAYLIST_URL.search(text)
    if channel:
        handle_channel(chat_id, channel.group(0))
        return
    match = YOUTUBE_URL.search(text)
    if not match:
        say(chat_id, "Пришли ссылку на YouTube.", reply_markup=KEYBOARD)
        return
    handle_play(chat_id, match.group(1), "list=" in text)


def poll():
    offset = None
    while True:
        params = {"timeout": 30, "allowed_updates": ["message", "callback_query"]}
        if offset is not None:
            params["offset"] = offset
        try:
            updates = tg("getUpdates", **params) or []
        except Exception as error:
            log(f"getUpdates failed: {error}")
            time.sleep(5)
            continue
        for update in updates:
            offset = update["update_id"] + 1
            callback = update.get("callback_query")
            if callback:
                try:
                    handle_callback(callback)
                except Exception as error:
                    log(f"callback {update['update_id']} failed: {error}")
                continue
            message = update.get("message")
            if not message:
                continue
            try:
                handle_message(message)
            except Exception as error:
                log(f"message {update['update_id']} failed: {error}")


def main():
    try:
        log(f"queue {queue_id()}")
    except Exception as error:
        log(f"queue lookup failed: {error}")
    threading.Thread(target=serve_resolver, daemon=True).start()
    poll()


if __name__ == "__main__":
    main()
