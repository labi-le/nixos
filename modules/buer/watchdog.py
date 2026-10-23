#!/usr/bin/env python3
import argparse
import datetime as dt
import hashlib
import hmac
import http.client
import json
import os
import sqlite3
import sys
import urllib.error
import urllib.request
import uuid

API = "https://api.github.com"
PAGE = 100
ACCEPTED = {200, 201, 202, 204}
REJECTED = {401, 403, 404, 422}
REPLAYABLE = {
    ("issue_comment", "created"),
    ("pull_request_review_comment", "created"),
    ("pull_request", "opened"),
    ("pull_request", "reopened"),
    ("pull_request", "ready_for_review"),
    ("pull_request", "closed"),
}


def iso_now():
    return dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def retry_stamp(seconds):
    return (dt.datetime.now(dt.timezone.utc) + dt.timedelta(seconds=seconds)).strftime(
        "%Y-%m-%dT%H:%M:%SZ"
    )


def request_json(url, token):
    request = urllib.request.Request(
        url,
        headers={
            "Authorization": "Bearer " + token,
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "buer-watchdog",
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            return json.loads(response.read())
    except urllib.error.HTTPError:
        raise
    except (http.client.HTTPException, ValueError) as exc:
        raise OSError(describe(exc)) from exc


def parse_stamp(value):
    stamp = dt.datetime.fromisoformat(str(value).replace("Z", "+00:00"))
    if stamp.tzinfo is None:
        stamp = stamp.replace(tzinfo=dt.timezone.utc)
    return stamp


def nearest(items, stamp_key, target, horizon):
    best = None
    for item in items:
        raw = item.get(stamp_key)
        if not raw:
            continue
        delta = abs((parse_stamp(raw) - target).total_seconds())
        if delta <= horizon and (best is None or delta < best[0]):
            best = (delta, item)
    return best[1] if best else None


def repository_object(token, repo):
    return request_json(f"{API}/repos/{repo}", token)


def make_issue_payload(token, repo, comment):
    issue = request_json(comment["issue_url"], token)
    return {
        "action": "created",
        "issue": issue,
        "comment": comment,
        "repository": repository_object(token, repo),
        "sender": comment.get("user") or {},
    }


def build_issue_comment(token, repo, delivered_at, horizon):
    comments = request_json(
        f"{API}/repos/{repo}/issues/comments?sort=created&direction=desc&per_page={PAGE}",
        token,
    )
    comment = nearest(comments, "created_at", delivered_at, horizon)
    if comment is None:
        return None
    return make_issue_payload(token, repo, comment)


def make_review_payload(token, repo, comment):
    pull = request_json(comment["pull_request_url"], token)
    return {
        "action": "created",
        "comment": comment,
        "pull_request": pull,
        "repository": repository_object(token, repo),
        "sender": comment.get("user") or {},
    }


def build_review_comment(token, repo, delivered_at, horizon):
    comments = request_json(
        f"{API}/repos/{repo}/pulls/comments?sort=created&direction=desc&per_page={PAGE}",
        token,
    )
    comment = nearest(comments, "created_at", delivered_at, horizon)
    if comment is None:
        return None
    return make_review_payload(token, repo, comment)


def build_pull_request(token, repo, action, delivered_at, horizon):
    stamp_key = {"opened": "created_at", "closed": "closed_at"}.get(
        action, "updated_at"
    )
    pulls = request_json(
        f"{API}/repos/{repo}/pulls?state=all&sort=updated&direction=desc&per_page={PAGE}",
        token,
    )
    pull = nearest(pulls, stamp_key, delivered_at, horizon)
    if pull is None:
        return None
    pull["merged"] = bool(pull.get("merged_at"))
    return {
        "action": action,
        "pull_request": pull,
        "repository": repository_object(token, repo),
        "sender": pull.get("user") or {},
    }


def build_payload(token, repo, event, action, delivered_at, horizon):
    if event == "pull_request":
        return build_pull_request(token, repo, action, delivered_at, horizon)
    if event == "issue_comment":
        return build_issue_comment(token, repo, delivered_at, horizon)
    if event == "pull_request_review_comment":
        return build_review_comment(token, repo, delivered_at, horizon)
    return None


def object_summary(payload):
    comment = payload.get("comment")
    if comment is not None:
        return "comment=" + str(comment.get("html_url"))
    pull = payload.get("pull_request") or {}
    return "pull=" + str(pull.get("html_url"))


def describe(exc):
    if isinstance(exc, urllib.error.HTTPError):
        return f"HTTP {exc.code}"
    return f"{type(exc).__name__}: {exc}"


def deliver(endpoint, secret, event, payload):
    body = json.dumps(payload).encode()
    signature = hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()
    delivery = str(uuid.uuid4())
    request = urllib.request.Request(
        endpoint,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "X-GitHub-Event": event,
            "X-GitHub-Delivery": delivery,
            "X-Hub-Signature-256": "sha256=" + signature,
            "User-Agent": "GitHub-Hookshot/buer-watchdog",
        },
    )
    try:
        response = urllib.request.urlopen(request, timeout=30)
        status = response.status
        response.read()
    except urllib.error.HTTPError as exc:
        status = exc.code
        exc.read()
    return delivery, status


def event_state(db_path, delivery):
    if not db_path:
        return None
    try:
        connection = sqlite3.connect(db_path, timeout=5)
        row = connection.execute(
            "select state, coalesce(last_error, '') from events where delivery_id = ?",
            (delivery,),
        ).fetchone()
        connection.close()
        return row
    except sqlite3.Error as exc:
        return ("db-error", str(exc))


def load_state(path):
    try:
        with open(path, encoding="utf-8") as handle:
            return json.load(handle)
    except (OSError, json.JSONDecodeError):
        return {"deliveries": {}}


def save_state(path, state, keep_days):
    cutoff = dt.datetime.now(dt.timezone.utc) - dt.timedelta(days=keep_days)
    kept = {}
    for key, value in state.get("deliveries", {}).items():
        try:
            when = parse_stamp(value.get("at", ""))
        except (ValueError, TypeError):
            continue
        if when > cutoff:
            kept[key] = value
    state["deliveries"] = kept
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(state, handle, indent=2, sort_keys=True)
    os.replace(temporary, path)


def hook_ids(token, repo):
    hooks = request_json(f"{API}/repos/{repo}/hooks", token)
    return [
        hook.get("id")
        for hook in hooks
        if ((hook.get("config") or {}).get("url") or "")
        .rstrip("/")
        .endswith("/webhook/github")
    ]


def failed_deliveries(token, repo, hook_id, horizon_from):
    deliveries = request_json(
        f"{API}/repos/{repo}/hooks/{hook_id}/deliveries?per_page={PAGE}", token
    )
    candidates = []
    for delivery in deliveries:
        delivered_at = delivery.get("delivered_at")
        if not delivered_at:
            continue
        try:
            when = parse_stamp(delivered_at)
        except ValueError:
            continue
        if when < horizon_from:
            continue
        status = delivery.get("status_code")
        candidates.append(
            (
                when,
                str(delivery.get("id")),
                delivery.get("event") or "",
                delivery.get("action") or "",
                status if isinstance(status, int) else -1,
            )
        )
    candidates.sort()
    return candidates


def payload_row(db_path, needle):
    if not db_path:
        return None
    try:
        connection = sqlite3.connect(db_path, timeout=5)
        row = connection.execute(
            "select state, coalesce(last_error, '') from events where payload_json like ? order by rowid desc limit 1",
            ("%" + needle + "%",),
        ).fetchone()
        connection.close()
        return row
    except sqlite3.Error as exc:
        return ("db-error", str(exc))


def comment_needle(event, comment):
    marker = "issuecomment-" if event == "issue_comment" else "discussion_r"
    return marker + str(comment["id"])


def activity_comments(token, repo, horizon_from):
    feeds = (
        (
            "issue_comment",
            f"{API}/repos/{repo}/issues/comments?sort=created&direction=desc&per_page={PAGE}",
        ),
        (
            "pull_request_review_comment",
            f"{API}/repos/{repo}/pulls/comments?sort=created&direction=desc&per_page={PAGE}",
        ),
    )
    found = []
    for event, feed in feeds:
        for comment in request_json(feed, token):
            if parse_stamp(comment["created_at"]) >= horizon_from:
                found.append((event, comment))
    return found


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lookback", type=int, default=900)
    parser.add_argument("--map-horizon", type=int, default=150)
    parser.add_argument("--max-replays", type=int, default=5)
    parser.add_argument("--keep-days", type=int, default=7)
    parser.add_argument("--retry-after", type=int, default=1800)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--strict", action="store_true")
    arguments = parser.parse_args()

    token = os.environ.get("GITHUB_WATCH_TOKEN") or os.environ.get("GITHUB_TOKEN") or ""
    secret = os.environ.get("GITHUB_WEBHOOK_SECRET") or ""
    endpoint = os.environ.get("WATCH_ENDPOINT", "http://127.0.0.1:6543/webhook/github")
    state_dir = os.environ.get("WATCH_STATE_DIR", "/var/lib/buer-watch")
    db_path = os.environ.get("WATCH_DB", "")
    repos = [
        item.strip()
        for item in os.environ.get("WATCH_REPOS", "").split(",")
        if item.strip()
    ]

    if not token:
        print("no GITHUB_WATCH_TOKEN or GITHUB_TOKEN in the environment", file=sys.stderr)
        return 2
    if not repos:
        print("no WATCH_REPOS in the environment", file=sys.stderr)
        return 2
    if not secret and not arguments.dry_run:
        print("no GITHUB_WEBHOOK_SECRET in the environment", file=sys.stderr)
        return 2

    state_path = os.path.join(state_dir, "state.json")
    first_run = not os.path.exists(state_path)
    if first_run and arguments.lookback > 300:
        print(f"first run: lookback trimmed from {arguments.lookback}s to 300s")
        arguments.lookback = 300
    state = load_state(state_path)
    seen = state.setdefault("deliveries", {})
    errors = []
    replayed = 0
    replayed_objects = set()
    horizon_from = dt.datetime.now(dt.timezone.utc) - dt.timedelta(
        seconds=arguments.lookback
    )

    for repo in repos:
        try:
            hooks = hook_ids(token, repo)
        except OSError as exc:
            if isinstance(exc, urllib.error.HTTPError) and exc.code == 404:
                print(
                    f"{repo}: the deliveries list needs a repository admin token; relying on the activity scan"
                )
            else:
                errors.append(f"{repo}: hook listing failed: {describe(exc)}")
            hooks = []
        for hook_id in hooks:
            try:
                candidates = failed_deliveries(token, repo, hook_id, horizon_from)
            except OSError as exc:
                errors.append(
                    f"{repo} hook {hook_id}: delivery listing failed: {describe(exc)}"
                )
                continue
            for when, delivery_id, event, action, status in candidates:
                entry = seen.get(delivery_id)
                if entry is not None:
                    retry_after = entry.get("retry_after")
                    if not retry_after:
                        continue
                    if parse_stamp(retry_after) > dt.datetime.now(dt.timezone.utc):
                        continue
                try:
                    if status in ACCEPTED:
                        seen[delivery_id] = {
                            "at": iso_now(),
                            "outcome": f"delivered {status}",
                        }
                        continue
                    if status in REJECTED:
                        print(
                            f"{repo} {delivery_id} {event}.{action} answered {status}; not a transport loss, leaving it alone"
                        )
                        seen[delivery_id] = {
                            "at": iso_now(),
                            "outcome": f"answered {status}",
                        }
                        continue
                    if (event, action) not in REPLAYABLE:
                        print(
                            f"{repo} {delivery_id} {event}.{action} failed with {status}; no replayer"
                        )
                        seen[delivery_id] = {
                            "at": iso_now(),
                            "outcome": f"failed {status}, no replayer",
                        }
                        continue
                    if replayed >= arguments.max_replays:
                        print(
                            f"{repo} {delivery_id}: replay budget exhausted, next run takes it"
                        )
                        break
                    payload = build_payload(
                        token, repo, event, action, when, arguments.map_horizon
                    )
                except OSError as exc:
                    errors.append(
                        f"{repo} {delivery_id}: reconstruction failed: {describe(exc)}"
                    )
                    continue
                if payload is None:
                    print(
                        f"{repo} {delivery_id} {event}.{action} failed with {status}; nothing matching within {arguments.map_horizon}s"
                    )
                    seen[delivery_id] = {
                        "at": iso_now(),
                        "outcome": f"failed {status}, no matching object",
                    }
                    continue
                summary = object_summary(payload)
                identity = event + " " + summary
                if identity in replayed_objects:
                    print(
                        f"{repo} {delivery_id} {event}.{action} {summary}: already replayed this run"
                    )
                    seen[delivery_id] = {
                        "at": iso_now(),
                        "outcome": summary + ", replayed once this run",
                    }
                    continue
                if arguments.dry_run:
                    print(
                        f"would replay {repo} {delivery_id} {event}.{action} {summary}"
                    )
                    replayed_objects.add(identity)
                    continue
                try:
                    delivery_uuid, post_status = deliver(
                        endpoint, secret, event, payload
                    )
                except OSError as exc:
                    errors.append(
                        f"{repo} {delivery_id}: replay post failed: {describe(exc)}"
                    )
                    continue
                if not 200 <= post_status < 300:
                    errors.append(
                        f"{repo} {delivery_id}: replay answered HTTP {post_status}"
                    )
                    seen[delivery_id] = {
                        "at": iso_now(),
                        "outcome": f"replay refused HTTP {post_status}",
                        "retry_after": retry_stamp(arguments.retry_after),
                    }
                    save_state(state_path, state, arguments.keep_days)
                    continue
                outcome = f"replayed HTTP {post_status} as {delivery_uuid}"
                row = event_state(db_path, delivery_uuid)
                rate_limited = False
                if row is not None:
                    outcome += f"; router={row[0]} {row[1]}".rstrip()
                    rate_limited = row[0] == "skipped" and "rate limit" in row[1]
                    if rate_limited:
                        print(
                            f"warning: the robot's rate limit dropped the replay of {repo} {delivery_id}: {row[1]}"
                        )
                print(f"{repo} {delivery_id} {event}.{action} {summary}: {outcome}")
                seen[delivery_id] = {"at": iso_now(), "outcome": outcome}
                if rate_limited:
                    seen[delivery_id]["retry_after"] = retry_stamp(arguments.retry_after)
                save_state(state_path, state, arguments.keep_days)
                replayed_objects.add(identity)
                replayed += 1

        if db_path:
            try:
                comments = activity_comments(token, repo, horizon_from)
            except OSError as exc:
                errors.append(f"{repo}: activity scan failed: {describe(exc)}")
                comments = []
            for event, comment in comments:
                needle = comment_needle(event, comment)
                entry = seen.get(needle)
                if entry is not None:
                    retry_after = entry.get("retry_after")
                    if not retry_after:
                        continue
                    if parse_stamp(retry_after) > dt.datetime.now(dt.timezone.utc):
                        continue
                row = payload_row(db_path, needle)
                if row is not None and row[0] == "db-error":
                    errors.append(f"{repo}: events table unreadable: {row[1]}")
                    break
                if row is not None and not (
                    row[0] == "skipped" and "rate limit" in row[1]
                ):
                    continue
                reason = (
                    "never reached the router"
                    if row is None
                    else f"the rate limit dropped it ({row[1]})"
                )
                if replayed >= arguments.max_replays:
                    print(f"{repo} {needle}: replay budget exhausted, next run takes it")
                    break
                try:
                    payload = (
                        make_issue_payload(token, repo, comment)
                        if event == "issue_comment"
                        else make_review_payload(token, repo, comment)
                    )
                except OSError as exc:
                    errors.append(
                        f"{repo} {needle}: reconstruction failed: {describe(exc)}"
                    )
                    continue
                summary = object_summary(payload)
                identity = event + " " + summary
                if identity in replayed_objects:
                    continue
                print(f"{repo} {needle}: {reason}; replaying")
                if arguments.dry_run:
                    replayed_objects.add(identity)
                    continue
                try:
                    delivery_uuid, post_status = deliver(
                        endpoint, secret, event, payload
                    )
                except OSError as exc:
                    errors.append(
                        f"{repo} {needle}: replay post failed: {describe(exc)}"
                    )
                    continue
                if not 200 <= post_status < 300:
                    errors.append(f"{repo} {needle}: replay answered HTTP {post_status}")
                    seen[needle] = {
                        "at": iso_now(),
                        "outcome": f"replay refused HTTP {post_status}",
                        "retry_after": retry_stamp(arguments.retry_after),
                    }
                    save_state(state_path, state, arguments.keep_days)
                    continue
                outcome = f"replayed HTTP {post_status} as {delivery_uuid}"
                new_row = event_state(db_path, delivery_uuid)
                if new_row is not None:
                    outcome += f"; router={new_row[0]} {new_row[1]}".rstrip()
                print(f"{repo} {needle} {summary}: {outcome}")
                seen[needle] = {"at": iso_now(), "outcome": outcome}
                if (
                    new_row is not None
                    and new_row[0] == "skipped"
                    and "rate limit" in new_row[1]
                ):
                    seen[needle]["retry_after"] = retry_stamp(arguments.retry_after)
                    print(
                        f"warning: the rate limit dropped the replay of {repo} {needle}: {new_row[1]}"
                    )
                save_state(state_path, state, arguments.keep_days)
                replayed_objects.add(identity)
                replayed += 1

    state["last_run"] = iso_now()
    if not arguments.dry_run:
        save_state(state_path, state, arguments.keep_days)
    for error in errors:
        print(f"error: {error}")
    if errors and arguments.strict:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
