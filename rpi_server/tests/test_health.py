from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_is_public(client: TestClient) -> None:
    response = client.get("/health")
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ok"
    assert body["version"]


def test_root_lists_links(client: TestClient) -> None:
    response = client.get("/")
    assert response.status_code == 200
    assert response.json()["health"] == "/health"


def test_request_id_is_echoed(client: TestClient) -> None:
    response = client.get("/health", headers={"X-Request-ID": "abc-123"})
    assert response.headers["X-Request-ID"] == "abc-123"


def test_missing_token_is_unauthorized(client: TestClient) -> None:
    response = client.get("/api/v1/dashboard/summary")
    assert response.status_code == 401
    body = response.json()
    assert body["success"] is False
    assert body["error_code"] == "UNAUTHORIZED"
    assert body["request_id"]


def test_invalid_body_returns_validation_error(client: TestClient) -> None:
    response = client.post(
        "/api/v1/auth/login", json={"email": "not-an-email"}
    )
    assert response.status_code == 422
    body = response.json()
    assert body["error_code"] == "VALIDATION_ERROR"
    assert body["details"]["errors"]


def test_unknown_route_returns_json_404(client: TestClient) -> None:
    response = client.get("/api/v1/does-not-exist")
    assert response.status_code == 404
    assert response.json()["error_code"] == "NOT_FOUND"


def test_wrong_method_returns_json_405(client: TestClient) -> None:
    response = client.delete("/api/v1/auth/login")
    assert response.status_code == 405
    assert response.json()["error_code"] == "METHOD_NOT_ALLOWED"


def test_openapi_is_available(client: TestClient) -> None:
    response = client.get("/openapi.json")
    assert response.status_code == 200
    assert response.json()["info"]["title"]


def test_readiness_reports_mysql_only(client: TestClient) -> None:
    from app.database.mysql.session import get_db

    class OkSession:
        def execute(self, *_a, **_k):
            return None

    app = client.app
    app.dependency_overrides[get_db] = lambda: OkSession()
    try:
        response = client.get("/health/ready")
    finally:
        app.dependency_overrides.pop(get_db, None)
    assert response.status_code == 200
    assert response.json() == {"status": "ready", "checks": {"mysql": "ok"}}


def test_readiness_degraded_when_mysql_down(client: TestClient) -> None:
    from app.database.mysql.session import get_db

    class BrokenSession:
        def execute(self, *_a, **_k):
            raise RuntimeError("down")

    app = client.app
    app.dependency_overrides[get_db] = lambda: BrokenSession()
    try:
        response = client.get("/health/ready")
    finally:
        app.dependency_overrides.pop(get_db, None)
    assert response.status_code == 503
    assert response.json() == {
        "status": "degraded",
        "checks": {"mysql": "unavailable"},
    }
