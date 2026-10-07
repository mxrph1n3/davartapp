#!/usr/bin/env python3
"""E2E: two staging users exchange personal messages via HTTP API."""

from __future__ import annotations

import hashlib
import json
import socket
import sys
import urllib.error
import urllib.request

API = "http://217.198.6.88:3000/api"
REDIS_HOST = "217.198.6.88"
REDIS_PORT = 6379
PHONE_A = "+79001110001"
PHONE_B = "+79001110002"
OTP = "4242"


def otp_hash(code: str) -> str:
    return hashlib.sha256(f"davart-otp:{code}".encode()).hexdigest()


def redis_cmd(sock: socket.socket, *parts: str) -> bytes:
    buf = f"*{len(parts)}\r\n"
    for p in parts:
        b = str(p).encode()
        buf += f"${len(b)}\r\n{b.decode()}\r\n"
    sock.sendall(buf.encode())
    return sock.recv(8192)


def inject_otps() -> None:
    h = otp_hash(OTP)
    s = socket.create_connection((REDIS_HOST, REDIS_PORT), timeout=8)
    try:
        pong = redis_cmd(s, "PING")
        if b"PONG" not in pong:
            raise RuntimeError(f"Redis PING failed: {pong!r}")
        for phone in (PHONE_A, PHONE_B):
            redis_cmd(s, "DEL", f"otp:rate:{phone}")
            redis_cmd(s, "DEL", f"otp:verify:lock:{phone}")
            redis_cmd(s, "DEL", f"otp:verify:attempts:{phone}")
            out = redis_cmd(s, "SET", f"otp:{phone}", h, "EX", "300")
            if b"OK" not in out:
                raise RuntimeError(f"SET otp failed for {phone}: {out!r}")
    finally:
        s.close()
    print("OK: injected OTP for test phones")


def http_json(method: str, path: str, body: dict | None = None, token: str | None = None):
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(
        f"{API}{path}",
        data=data,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            payload = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            payload = raw
        return e.code, payload


def login(phone: str) -> dict:
    code, payload = http_json(
        "POST",
        "/auth/verify-otp",
        {"phone": phone, "code": OTP},
    )
    if code != 200 or not isinstance(payload, dict) or "accessToken" not in payload:
        raise RuntimeError(f"login failed {phone}: {code} {payload}")
    print(f"OK: logged in {phone} user={payload.get('user', {}).get('id')}")
    return payload


def main() -> int:
    print("==> health")
    code, health = http_json("GET", "/health")
    print(code, health)
    if code != 200:
        return 1

    print("==> inject OTP via Redis")
    inject_otps()

    print("==> login A/B")
    a = login(PHONE_A)
    b = login(PHONE_B)
    token_a = a["accessToken"]
    token_b = b["accessToken"]
    id_a = a["user"]["id"]
    id_b = b["user"]["id"]

    print("==> A opens personal chat with B")
    code, chat = http_json(
        "POST",
        "/chats/personal",
        {"userId": id_b},
        token=token_a,
    )
    print(code, chat)
    if code != 201 and code != 200:
        # Nest often returns 201 for create; accept 200 too
        if not (isinstance(chat, dict) and chat.get("id")):
            return 1
    chat_id = chat["id"]
    print(f"OK: chat_id={chat_id}")

    print("==> A sends message")
    code, msg1 = http_json(
        "POST",
        f"/chats/{chat_id}/messages",
        {"type": "text", "content": "Привет от A — e2e"},
        token=token_a,
    )
    print(code, msg1)
    if code not in (200, 201) or not isinstance(msg1, dict):
        return 1

    print("==> B lists chats / reads messages")
    code, chats_b = http_json("GET", "/chats", token=token_b)
    print("chats status", code)
    if code != 200:
        return 1
    items = chats_b.get("items") if isinstance(chats_b, dict) else chats_b
    if isinstance(chats_b, list):
        items = chats_b
    found = False
    if isinstance(items, list):
        found = any(isinstance(c, dict) and c.get("id") == chat_id for c in items)
    print("B sees chat:", found)
    if not found:
        print("FAIL: B does not see personal chat in list")
        return 1

    code, msgs = http_json(
        "GET",
        f"/chats/{chat_id}/messages?limit=20",
        token=token_b,
    )
    print("messages status", code)
    if code != 200:
        return 1
    msg_items = msgs.get("items") if isinstance(msgs, dict) else []
    texts = [m.get("content") for m in msg_items if isinstance(m, dict)]
    print("B messages:", texts)
    if "Привет от A — e2e" not in texts:
        print("FAIL: B cannot read A's message")
        return 1

    print("==> B replies")
    code, msg2 = http_json(
        "POST",
        f"/chats/{chat_id}/messages",
        {"type": "text", "content": "Ответ от B — e2e"},
        token=token_b,
    )
    print(code, msg2)
    if code not in (200, 201):
        return 1

    code, msgs_a = http_json(
        "GET",
        f"/chats/{chat_id}/messages?limit=20",
        token=token_a,
    )
    msg_items_a = msgs_a.get("items") if isinstance(msgs_a, dict) else []
    texts_a = [m.get("content") for m in msg_items_a if isinstance(m, dict)]
    print("A messages:", texts_a)
    if "Ответ от B — e2e" not in texts_a:
        print("FAIL: A cannot read B's reply")
        return 1

    print("==> match-phones (contacts API)")
    code, matched = http_json(
        "POST",
        "/chats/match-phones",
        {"phones": [PHONE_B, PHONE_A]},
        token=token_a,
    )
    print(code, matched)
    if code == 404:
        print("WARN: match-phones not deployed yet on staging")
    elif code != 200:
        print("FAIL: match-phones error")
        return 1
    else:
        phones = {
            m.get("phone")
            for m in (matched.get("matches") or [])
            if isinstance(m, dict)
        }
        if PHONE_B not in phones:
            print("FAIL: match-phones did not find B")
            return 1
        print("OK: match-phones found B")

    print("\nPASS: two accounts can message each other on staging")
    print(f"users: {id_a} <-> {id_b}, chat: {chat_id}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
