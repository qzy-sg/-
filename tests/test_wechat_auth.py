def test_wechat_login_binds_identity(client):
    first = client.post("/api/v1/auth/wechat/challenge")
    assert first.status_code == 200
    state = first.json()["state"]
    subject = "wxsub_abc12345"
    login = client.post("/api/v1/auth/wechat", json={"state": state, "subject": subject})
    assert login.status_code == 200
    body = login.json()
    assert body["access_token"]
    assert body["user"]["display_name"] == "微信用户2345"

    again = client.post("/api/v1/auth/wechat/challenge").json()
    second = client.post("/api/v1/auth/wechat", json={"state": again["state"], "subject": subject})
    assert second.json()["user"]["id"] == body["user"]["id"]

    other = client.post("/api/v1/auth/wechat/challenge").json()
    third = client.post("/api/v1/auth/wechat", json={"state": other["state"], "subject": "wxsub_zzzz9999"})
    assert third.json()["user"]["id"] != body["user"]["id"]

    reused = client.post("/api/v1/auth/wechat", json={"state": state, "subject": subject})
    assert reused.status_code == 401
