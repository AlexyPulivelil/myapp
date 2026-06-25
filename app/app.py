import os
import logging

import psycopg2
import psycopg2.extras
from flask import Flask, jsonify, request

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)

app = Flask(__name__)
DATABASE_URL = os.environ["DATABASE_URL"]


def get_conn():
    return psycopg2.connect(DATABASE_URL, connect_timeout=5)


def init_db():
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS items (
                    id SERIAL PRIMARY KEY,
                    name TEXT NOT NULL,
                    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                )
                """
            )
        conn.commit()
    logger.info("Database initialised")


@app.route("/health")
def health():
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return jsonify({"status": "ok", "db": "connected"}), 200
    except Exception as exc:
        logger.error("Health check failed: %s", exc)
        return jsonify({"status": "error", "db": "unreachable", "detail": str(exc)}), 503


@app.route("/items", methods=["GET"])
def list_items():
    try:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute("SELECT id, name, created_at FROM items ORDER BY created_at DESC")
                rows = cur.fetchall()
        return jsonify([dict(r) for r in rows]), 200
    except Exception as exc:
        logger.error("GET /items failed: %s", exc)
        return jsonify({"error": "database unavailable"}), 503


@app.route("/items", methods=["POST"])
def create_item():
    body = request.get_json(silent=True)
    if not body or not isinstance(body.get("name"), str) or not body["name"].strip():
        return jsonify({"error": "request body must include a non-empty 'name' string"}), 400

    name = body["name"].strip()
    try:
        with get_conn() as conn:
            with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
                cur.execute(
                    "INSERT INTO items (name) VALUES (%s) RETURNING id, name, created_at",
                    (name,),
                )
                row = dict(cur.fetchone())
            conn.commit()
        return jsonify(row), 201
    except Exception as exc:
        logger.error("POST /items failed: %s", exc)
        return jsonify({"error": "database unavailable"}), 503


if __name__ == "__main__":
    init_db()
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port)
