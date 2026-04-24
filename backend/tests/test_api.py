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


def test_hide_range_marks_only_current_device_events_as_unrecorded(client):
    first_device = register_device(client)
    second_device = register_device(client)
    first_headers = {"Authorization": f"Bearer {first_device['device_token']}"}
    second_headers = {"Authorization": f"Bearer {second_device['device_token']}"}
    now = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    hidden_start = now - timedelta(minutes=2)
    hidden_middle = hidden_start + timedelta(minutes=1)
    hidden_end = hidden_start + timedelta(minutes=2)

    first_upload = client.post(
        "/v1/events/batch",
        headers=first_headers,
        json={
            "batch_id": "batch-hide-first",
            "events": [
                {
                    "event_id": "evt-hide-1",
                    "occurred_at": hidden_start.isoformat(),
                    "key_code": 12,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.TextEdit",
                },
                {
                    "event_id": "evt-hide-2",
                    "occurred_at": hidden_middle.isoformat(),
                    "key_code": 13,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.TextEdit",
                },
            ],
        },
    )
    assert first_upload.status_code == 200

    second_upload = client.post(
        "/v1/events/batch",
        headers=second_headers,
        json={
            "batch_id": "batch-hide-second",
            "events": [
                {
                    "event_id": "evt-hide-other-device",
                    "occurred_at": hidden_middle.isoformat(),
                    "key_code": 14,
                    "modifier_flags": 0,
                    "event_type": "keyDown",
                    "source_app": "com.apple.TextEdit",
                }
            ],
        },
    )
    assert second_upload.status_code == 200

    first_hide = client.post(
        "/v1/events/hide-range",
        headers=first_headers,
        json={
            "start_time": hidden_start.isoformat(),
            "end_time": hidden_end.isoformat(),
        },
    )
    assert first_hide.status_code == 200
    assert first_hide.json()["updated_count"] == 2

    second_hide = client.post(
        "/v1/events/hide-range",
        headers=first_headers,
        json={
            "start_time": hidden_start.isoformat(),
            "end_time": hidden_end.isoformat(),
        },
    )
    assert second_hide.status_code == 200
    assert second_hide.json()["updated_count"] == 0

    first_keycodes = client.get(
        "/v1/stats/keycodes",
        headers=first_headers,
        params={
            "start_time": (hidden_start - timedelta(minutes=1)).isoformat(),
            "end_time": (hidden_end + timedelta(minutes=1)).isoformat(),
            "limit": 10,
        },
    )
    assert first_keycodes.status_code == 200
    first_items = first_keycodes.json()["items"]
    assert first_items[0]["key_code"] == -1
    assert first_items[0]["count"] == 2

    first_summary = client.get(
        "/v1/stats/summary",
        headers=first_headers,
        params={
            "start_time": (hidden_start - timedelta(minutes=1)).isoformat(),
            "end_time": (hidden_end + timedelta(minutes=1)).isoformat(),
        },
    )
    assert first_summary.status_code == 200
    assert first_summary.json()["total_events"] == 2

    second_keycodes = client.get(
        "/v1/stats/keycodes",
        headers=second_headers,
        params={
            "start_time": (hidden_start - timedelta(minutes=1)).isoformat(),
            "end_time": (hidden_end + timedelta(minutes=1)).isoformat(),
            "limit": 10,
        },
    )
    assert second_keycodes.status_code == 200
    second_items = second_keycodes.json()["items"]
    assert second_items[0]["key_code"] == 14
    assert second_items[0]["count"] == 1


def test_hide_range_rejects_more_than_24_hours(client):
    device = register_device(client)
    headers = {"Authorization": f"Bearer {device['device_token']}"}
    start_time = datetime.now(timezone.utc).replace(second=0, microsecond=0)
    end_time = start_time + timedelta(hours=24, minutes=1)

    response = client.post(
        "/v1/events/hide-range",
        headers=headers,
        json={
            "start_time": start_time.isoformat(),
            "end_time": end_time.isoformat(),
        },
    )

    assert response.status_code == 422
    assert response.json()["detail"] == "Single hide range cannot exceed 24 hours."
