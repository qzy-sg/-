def test_mock_chat_stream_chunks():
    from house_design.ai import MockAIProvider

    pieces = list(MockAIProvider().chat_stream([{"role": "user", "content": "你好"}]))
    assert pieces
    assert "".join(pieces).startswith("这是 Mock 回复")


def test_ai_consult_stream_sse_shape():
    from house_design.database import Session
    from house_design.models import User
    from house_design.security import hash_password, new_id, utcnow
    from house_design.usecases import ai_consult_stream

    db = Session()
    user = User(
        id=new_id("usr"),
        email=f"stream_{new_id('x')}@local.test",
        password_hash=hash_password("demo-password"),
        created_at=utcnow(),
    )
    db.add(user)
    db.commit()

    chunks = list(ai_consult_stream(db, user, "两室怎么改"))
    assert any("event: phase.started" in item for item in chunks)
    assert any("event: assistant.delta" in item for item in chunks)
    assert any("event: task.completed" in item for item in chunks)
    joined = "".join(chunks)
    assert "Mock 回复" in joined or "reply" in joined
