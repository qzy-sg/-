def test_mock_sms_is_one_time(client):
    phone = "13800138000"
    issued = client.post("/api/v1/auth/sms/send", json={"phone": phone})
    assert issued.status_code == 200, issued.text
    code = issued.json()["dev_code"]
    assert len(code) == 6

    again = client.post("/api/v1/auth/sms/send", json={"phone": phone})
    assert again.status_code == 429
    assert again.json()["code"] == "RATE_LIMITED"

    registered = client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "code": code, "password": "secret1"},
    )
    assert registered.status_code == 201, registered.text
    assert registered.json()["access_token"]

    reused = client.post("/api/v1/auth/phone", json={"phone": phone, "code": code})
    assert reused.status_code == 401

    fresh = client.post("/api/v1/auth/sms/send", json={"phone": "13900139000"})
    assert fresh.status_code == 200
    missing = client.post(
        "/api/v1/auth/phone",
        json={"phone": "13900139000", "code": fresh.json()["dev_code"]},
    )
    assert missing.status_code == 404
