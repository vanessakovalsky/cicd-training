from fastapi.testclient import TestClient

from fretexpress.api import app

client = TestClient(app)


def test_health_repond_ok():
    reponse = client.get("/health")

    assert reponse.status_code == 200
    assert reponse.json() == {"statut": "ok"}


def test_version_est_exposee():
    reponse = client.get("/version")

    assert reponse.status_code == 200
    assert "version" in reponse.json()
