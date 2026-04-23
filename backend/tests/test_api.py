from datetime import datetime, timedelta, timezone


def register_device(client):
    response = client.post(
        "/v1/devices/register",
        json={
            "name": "Chen MacBook Pro",
            "platform": "macOS",
            "app_version": "0.1.0",
            "bootstrap_secret": "test-bootstrap-secret",
        },
    )
    assert response.status_code == 201
    return response.json()


def test_device_registration_and_batch_idempotency(client):
    device = register_device(client)
    headers = {"Authorization": f"Bearer {device['device_token']}"}

    payload = {
        "batch_id": "batch-001",
        "events": [
            {
                "event_id": "evt-1",
                "occurred_at": datetime.now(timezone.utc).isoformat(),
                "key_code": 12,
                "modifier_flags": 0,
                "event_type": "keyDown",
                "source_app": "com.apple.TextEdit",
            },
            {
                "event_id": "evt-2",
                "occurred_at": datetime.now(timezone.utc).isoformat(),
                "key_code": 13,
                "modifier_flags": 1,
                "event_type": "keyDown",
                "source_app": "com.apple.TextEdit",
            },
        ],
    }

    first = client.post("/v1/events/batch", headers=headers, json=payload)
    assert first.status_code == 200
    assert first.json()["inserted_count"] == 2
    assert first.json()["duplicate_count"] == 0

    second = client.post("/v1/events/batch", headers=headers, json=payload)
    assert second.status_code == 200
    assert second.json()["inserted_count"] == 2
    assert second.json()["duplicate_count"] == 0


def test_summary_returns_bucketed_stats(client):
    device = register_device(client)
    headers = {"Authorization": f"Bearer {device['device_token']}"}
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    earlier = now - timedelta(minutes=2)

    response = client.post(
        "/v1/events/batch",
        headers=headers,
        json={
            "batch_id": "batch-002",
            "events": [
                {
                    "event_id": "evt-summary-1",
                    "occurred_at": earlier.isoformat(),
                    "key_code": 14,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.Terminal",
                },
                {
                    "event_id": "evt-summary-2",
                    "occurred_at": now.isoformat(),
                    "key_code": 15,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.Terminal",
                },
            ],
        },
    )
    assert response.status_code == 200

    summary = client.get(
        "/v1/stats/summary",
        headers=headers,
        params={
            "start_time": (now - timedelta(minutes=5)).isoformat(),
            "end_time": (now + timedelta(minutes=1)).isoformat(),
        },
    )
    assert summary.status_code == 200
    body = summary.json()
    assert body["total_events"] == 2
    assert len(body["buckets"]) >= 1
    assert sum(bucket["count"] for bucket in body["buckets"]) == 2
    assert body["bucket"] == "hour"


def test_modifier_flags_accepts_large_legacy_values(client):
    device = register_device(client)
    headers = {"Authorization": f"Bearer {device['device_token']}"}

    response = client.post(
        "/v1/events/batch",
        headers=headers,
        json={
            "batch_id": "batch-legacy-flags",
            "events": [
                {
                    "event_id": "evt-legacy-flags",
                    "occurred_at": datetime.now(timezone.utc).isoformat(),
                    "key_code": 12,
                    "modifier_flags": 1179648,
                    "event_type": "keyDown",
                    "source_app": "com.apple.TextEdit",
                }
            ],
        },
    )

    assert response.status_code == 200
    assert response.json()["inserted_count"] == 1


def test_summary_supports_day_buckets_and_keycode_stats(client):
    device = register_device(client)
    headers = {"Authorization": f"Bearer {device['device_token']}"}
    now = datetime.now(timezone.utc).replace(hour=12, minute=0, second=0, microsecond=0)
    yesterday = now - timedelta(days=1)

    response = client.post(
        "/v1/events/batch",
        headers=headers,
        json={
            "batch_id": "batch-003",
            "events": [
                {
                    "event_id": "evt-day-1",
                    "occurred_at": yesterday.isoformat(),
                    "key_code": 12,
                    "modifier_flags": 1,
                    "event_type": "keyDown",
                    "source_app": "com.apple.Terminal",
                },
                {
                    "event_id": "evt-day-2",
                    "occurred_at": now.isoformat(),
                    "key_code": 12,
                    "modifier_flags": 8,
                    "event_type": "keyDown",
                    "source_app": "com.apple.Terminal",
                },
                {
                    "event_id": "evt-day-3",
                    "occurred_at": now.isoformat(),
                    "key_code": 13,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.Terminal",
                },
            ],
        },
    )
    assert response.status_code == 200

    summary = client.get(
        "/v1/stats/summary",
        headers=headers,
        params={
            "start_time": (now - timedelta(days=2)).isoformat(),
            "end_time": (now + timedelta(hours=1)).isoformat(),
            "bucket": "day",
        },
    )
    assert summary.status_code == 200
    body = summary.json()
    assert body["bucket"] == "day"
    assert len(body["buckets"]) >= 2

    keycodes = client.get(
        "/v1/stats/keycodes",
        headers=headers,
        params={
            "start_time": (now - timedelta(days=2)).isoformat(),
            "end_time": (now + timedelta(hours=1)).isoformat(),
            "limit": 10,
        },
    )
    assert keycodes.status_code == 200
    keycode_body = keycodes.json()
    assert keycode_body["total_events"] == 3
    assert keycode_body["items"][0]["key_code"] == 12
    assert keycode_body["items"][0]["count"] == 2
