from unittest.mock import MagicMock, patch

from app.config import Settings, get_settings
from app.llm import summarize
from fastapi.testclient import TestClient

from app.main import app

STUB_SETTINGS = Settings(llm_mode="stub")


def test_health():
    client = TestClient(app)
    assert client.get("/health").json() == {"status": "ok"}


def test_metrics_exposes_prometheus():
    client = TestClient(app)
    body = client.get("/metrics").text
    assert "python_info" in body or "process_" in body


def test_ready_ok():
    app.dependency_overrides[get_settings] = lambda: STUB_SETTINGS
    try:
        with (
            patch("app.main.psycopg.connect") as mock_pg,
            patch("app.main.redis.from_url") as mock_redis_from_url,
        ):
            mock_conn = MagicMock()
            mock_pg.return_value.__enter__.return_value = mock_conn
            mock_r = MagicMock()
            mock_r.ping.return_value = True
            mock_redis_from_url.return_value.__enter__.return_value = mock_r

            client = TestClient(app)
            assert client.get("/ready").json() == {"status": "ready"}
    finally:
        app.dependency_overrides.clear()


def test_ready_503_when_postgres_down():
    app.dependency_overrides[get_settings] = lambda: STUB_SETTINGS
    try:
        with (
            patch("app.main.psycopg.connect", side_effect=OSError("connection refused")),
            patch("app.main.redis.from_url") as mock_redis_from_url,
        ):
            mock_r = MagicMock()
            mock_r.ping.return_value = True
            mock_redis_from_url.return_value.__enter__.return_value = mock_r

            client = TestClient(app)
            res = client.get("/ready")
            assert res.status_code == 503
            body = res.json()
            assert body["status"] == "not_ready"
            assert any("postgres" in e for e in body["errors"])
    finally:
        app.dependency_overrides.clear()


def test_summarize_stub_happy_path():
    """Golden path: AI is stubbed; contract must stay stable for later infra work."""
    app.dependency_overrides[get_settings] = lambda: STUB_SETTINGS
    try:
        client = TestClient(app)
        res = client.post(
            "/v1/summarize",
            json={"text": "First sentence stays. Second is dropped."},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["mode"] == "stub"
        assert data["summary"] == "First sentence stays."
    finally:
        app.dependency_overrides.clear()


def test_summarize_unit_cap():
    long = "x" * 200
    out = summarize(long, STUB_SETTINGS)
    assert out.endswith("...")
    assert len(out) <= 160
