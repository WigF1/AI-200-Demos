"""
Quick unit tests, no Azure or Docker required.
Run with: pip install -r requirements.txt pytest && pytest
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from app import app  # noqa: E402


def client():
    app.testing = True
    return app.test_client()


def test_health():
    c = client()
    resp = c.get("/health")
    assert resp.status_code == 200
    assert resp.get_json()["status"] == "healthy"


def test_config_defaults():
    c = client()
    resp = c.get("/config")
    body = resp.get_json()
    assert resp.status_code == 200
    assert "websitesPortHint" in body


def test_classify_requires_text():
    c = client()
    resp = c.post("/classify", json={})
    assert resp.status_code == 400


def test_classify_happy_path():
    c = client()
    resp = c.post("/classify", json={"text": "hello world"})
    assert resp.status_code == 200
    body = resp.get_json()
    assert body["category"] in ("positive", "negative")
    assert "requestId" in body
