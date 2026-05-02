from prometheus_client import Counter, Gauge

anomaly_score = Gauge(
    "geode_anomaly_score",
    "IsolationForest anomaly score per Geode member (more negative = more anomalous)",
    ["instance", "member"],
)

last_inference_ts = Gauge(
    "geode_ai_last_inference_timestamp_seconds",
    "Unix timestamp of the last successful inference run",
    ["member"],
)

inference_errors = Counter(
    "geode_ai_inference_errors_total",
    "Total inference errors",
    ["member", "reason"],
)
