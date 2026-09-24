def test_account_profile_roundtrip(client):
    phone = "13700137000"
    issued = client.post("/api/v1/auth/sms/send", json={"phone": phone})
    assert issued.status_code == 200, issued.text
    code = issued.json()["dev_code"]

    registered = client.post(
        "/api/v1/auth/register",
        json={"phone": phone, "code": code, "password": "secret1"},
    )
    assert registered.status_code == 201, registered.text
    token = registered.json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}

    me = client.get("/api/v1/auth/me", headers=headers)
    assert me.status_code == 200, me.text
    body = me.json()
    assert body["provider"] == "phone"
    assert body["phone_masked"] == "137****7000"
    assert body["display_name"] == ""

    patched = client.patch(
        "/api/v1/auth/me",
        headers=headers,
        json={"display_name": "小林", "city": "杭州", "bio": "两居室暖色", "avatar_id": "mint"},
    )
    assert patched.status_code == 200, patched.text
    assert patched.json()["display_name"] == "小林"
    assert patched.json()["city"] == "杭州"
    assert patched.json()["bio"] == "两居室暖色"
    assert patched.json()["avatar_id"] == "mint"

    again = client.get("/api/v1/auth/me", headers=headers)
    assert again.status_code == 200
    assert again.json()["display_name"] == "小林"
    assert again.json()["avatar_id"] == "mint"
