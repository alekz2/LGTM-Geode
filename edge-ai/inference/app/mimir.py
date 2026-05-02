"""
Async Mimir HTTP client and feature vector builder.

Feature order must match features.json exactly (indices 0-9).
Both training (train.py) and inference read the same features.json to guarantee alignment.
"""

import json
import logging
import time
from pathlib import Path

import httpx
import numpy as np

logger = logging.getLogger(__name__)

FEATURES_JSON = Path(__file__).parent.parent.parent.parent / "features.json"
FEATURES: list[dict] = []


def _load_features() -> list[dict]:
    global FEATURES
    if FEATURES:
        return FEATURES
    # In the container, features.json is at /features.json (bind-mounted alongside models).
    # Fall back to the path relative to this file for local development.
    candidates = [
        Path("/features.json"),
        FEATURES_JSON,
    ]
    for path in candidates:
        if path.exists():
            FEATURES = sorted(json.loads(path.read_text()), key=lambda f: f["index"])
            logger.info("Loaded %d features from %s", len(FEATURES), path)
            return FEATURES
    raise FileNotFoundError("features.json not found in any expected location")


def _build_promql(feat: dict, member: str, lookback_minutes: int) -> list[tuple[str, str]]:
    """Return list of (name, promql) tuples for each raw series needed for this feature."""
    label_filter = f'job="geode", member="{member}"'
    win = f"{lookback_minutes}m"
    derived = feat["derived"]

    if derived == "ratio":
        area = feat["extra_labels"]["area"]
        return [
            (f"{feat['name']}__num",
             f'{feat["numerator_metric"]}{{area="{area}", {label_filter}}}'),
            (f"{feat['name']}__den",
             f'{feat["denominator_metric"]}{{area="{area}", {label_filter}}}'),
        ]
    elif derived == "rate":
        if feat.get("sum_by_member"):
            q = f'sum by (member) (rate({feat["metric"]}{{job="geode", member="{member}"}}[{win}]))'
        else:
            q = f'rate({feat["metric"]}{{{{job="geode", member="{member}"}}}}[{win}])'
        return [(feat["name"], q)]
    else:  # raw
        return [(feat["name"], f'{feat["metric"]}{{{{job="geode", member="{member}"}}}}')]


async def fetch_scalar(client: httpx.AsyncClient, mimir_url: str, promql: str) -> float | None:
    """Instant query returning the current scalar value (mean over scrape)."""
    try:
        r = await client.get(
            f"{mimir_url}/api/v1/query",
            params={"query": promql, "time": int(time.time())},
            timeout=10.0,
        )
        r.raise_for_status()
        data = r.json()
        results = data["data"]["result"]
        if not results:
            return None
        values = [float(s["value"][1]) for s in results if s["value"][1] not in ("NaN", "+Inf", "-Inf")]
        if not values:
            return None
        return float(np.mean(values))
    except Exception as exc:
        logger.warning("Mimir query failed (%s): %s", promql[:80], exc)
        return None


async def build_feature_vector(
    mimir_url: str, member: str, lookback_minutes: int
) -> list[float] | None:
    """Return a 10-element feature vector for the given member, or None on failure."""
    features = _load_features()
    vector: list[float | None] = [None] * len(features)

    async with httpx.AsyncClient() as client:
        for feat in features:
            idx = feat["index"]
            derived = feat["derived"]
            win = f"{lookback_minutes}m"
            label_filter = f'job="geode", member="{member}"'

            if derived == "ratio":
                area = feat["extra_labels"]["area"]
                num_q = f'avg_over_time({feat["numerator_metric"]}{{area="{area}", {label_filter}}}[{win}])'
                den_q = f'avg_over_time({feat["denominator_metric"]}{{area="{area}", {label_filter}}}[{win}])'
                num = await fetch_scalar(client, mimir_url, num_q)
                den = await fetch_scalar(client, mimir_url, den_q)
                if num is None or den is None or den == 0:
                    logger.warning("Missing heap ratio data for %s", member)
                    vector[idx] = 0.0
                else:
                    vector[idx] = num / den

            elif derived == "rate":
                if feat.get("sum_by_member"):
                    q = f'sum by (member) (rate({feat["metric"]}{{job="geode", member="{member}"}}[{win}]))'
                else:
                    q = f'rate({feat["metric"]}{{job="geode", member="{member}"}}[{win}])'
                val = await fetch_scalar(client, mimir_url, q)
                vector[idx] = max(val, 0.0) if val is not None else 0.0

            else:  # raw
                q = f'avg_over_time({feat["metric"]}{{job="geode", member="{member}"}}[{win}])'
                val = await fetch_scalar(client, mimir_url, q)
                vector[idx] = val if val is not None else 0.0

    missing = [features[i]["name"] for i, v in enumerate(vector) if v is None]
    if missing:
        logger.warning("Features with no data for %s: %s", member, missing)
        vector = [v if v is not None else 0.0 for v in vector]

    return [float(v) for v in vector]
