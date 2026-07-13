from fastapi.testclient import TestClient

from app.main import app


def test_health():
    # No `with` block: avoids running the lifespan (migrations/DB) — no database needed
    client = TestClient(app)
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.json() == {"status": "healthy"}
