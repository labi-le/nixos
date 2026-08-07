import json

from config import MAX_TEXT


def tail(text, lines):
    kept = text.splitlines()[-lines:]
    return "\n".join(kept)


def clamp(text):
    if len(text) <= MAX_TEXT:
        return text
    return "[truncated to the last %d chars]\n" % MAX_TEXT + text[-MAX_TEXT:]


def envelope(header, body=""):
    text = json.dumps(header, indent=2, ensure_ascii=False)
    if body:
        text += "\n\n" + body
    return clamp(text)
