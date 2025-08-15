import os
import time
import math
import socket
import threading
from typing import Dict, Any

from flask import Flask, request, jsonify
from prometheus_flask_exporter import PrometheusMetrics
from prometheus_client import Counter

app = Flask(__name__)

# Prometheus auto-instrumentation + /metrics endpoint
metrics = PrometheusMetrics(app, path="/metrics")
metrics.info(
    "app_info",
    "Application info",
    version=os.getenv("APP_VERSION", "0.1.0"),
    environment=os.getenv("ENV", "local"),
)

# Custom counters for illustrative purposes
slow_counter = Counter("slow_requests_total", "Count of /slow calls", ["status"])
cpu_counter = Counter("cpu_jobs_total", "Count of /cpu calls")


@app.get("/")
def index() -> Any:
    """Lekkie zapytanie do testów żywotności i routingów."""
    payload: Dict[str, Any] = {
        "status": "ok",
        "service": "k8s-thesis-app",
        "hostname": socket.gethostname(),
        "time": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "env": os.getenv("ENV", "local"),
        "version": os.getenv("APP_VERSION", "0.1.0"),
    }
    return jsonify(payload)


@app.get("/slow")
def slow() -> Any:
    """Symulacja opóźnienia. Parametr: seconds (float, 0..30)."""
    try:
        seconds_str = request.args.get("seconds", "1")
        seconds = float(seconds_str)
        if seconds < 0:
            seconds = 0.0
        if seconds > 30:
            seconds = 30.0
        start = time.perf_counter()
        time.sleep(seconds)
        elapsed = time.perf_counter() - start
        slow_counter.labels(status="ok").inc()
        return jsonify({
            "status": "slept",
            "requested_seconds": float(seconds_str),
            "slept_seconds": round(elapsed, 4),
        })
    except Exception as exc:  # noqa: BLE001
        slow_counter.labels(status="error").inc()
        return jsonify({"status": "error", "message": str(exc)}), 400


@app.get("/cpu")
def cpu() -> Any:
    """Symulacja obciążenia CPU.
    Parametry query:
      - seconds (float, 0..60; domyślnie 2)
      - workers (int, 1..64; domyślnie liczba rdzeni)
    """
    try:
        seconds = float(request.args.get("seconds", "2"))
        if seconds < 0:
            seconds = 0.0
        if seconds > 60:
            seconds = 60.0

        max_workers = max(1, os.cpu_count() or 1)
        workers = request.args.get("workers")
        if workers is None:
            workers = max_workers
        else:
            workers = int(workers)
            if workers < 1:
                workers = 1
            if workers > 64:
                workers = 64

        def _burn_cpu(duration: float) -> None:
            end = time.perf_counter() + duration
            x = 1.000001
            while time.perf_counter() < end:
                # Intensive but deterministic floating point ops
                x = math.sqrt(x) ** 2 + 1e-9  # keep CPU busy

        threads = [threading.Thread(target=_burn_cpu, args=(seconds,)) for _ in range(workers)]
        start = time.perf_counter()
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        elapsed = time.perf_counter() - start
        cpu_counter.inc()
        return jsonify({
            "status": "cpu_load_completed",
            "requested_seconds": seconds,
            "workers": workers,
            "cpu_count": max_workers,
            "elapsed_seconds": round(elapsed, 4),
        })
    except Exception as exc:  # noqa: BLE001
        return jsonify({"status": "error", "message": str(exc)}), 400


if __name__ == "__main__":
    # Lokalnie: python app/app.py
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8000")))