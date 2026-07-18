from types import SimpleNamespace

from fastapi.testclient import TestClient

from app.main import app
from app.database import get_db


class _FakeResult:
    def __init__(self, value):
        self._value = value

    def scalar_one_or_none(self):
        return self._value


class _FakeSession:
    """Yields an existing baker for any SELECT — registration must be closed."""

    async def execute(self, *_args, **_kwargs):
        return _FakeResult(SimpleNamespace(id="x", email="existing@example.com"))


async def _fake_db():
    yield _FakeSession()


def test_register_closed_when_baker_exists():
    app.dependency_overrides[get_db] = _fake_db
    try:
        client = TestClient(app)
        response = client.post(
            "/api/auth/register",
            json={
                "email": "new@example.com",
                "password": "secret123",
                "name": "Nowy",
                "phone": "+48123456789",
            },
        )
        assert response.status_code == 403
        assert response.json()["detail"] == "Rejestracja jest zamknięta"
    finally:
        app.dependency_overrides.clear()
