"""
Training script for Geode anomaly detection model.

Usage:
    python train.py --mimir-url http://192.168.0.153:9009/prometheus \
                    --output-dir models \
                    --lookback-hours 24

Outputs models/geode_anomaly.onnx. Run on Ironman, then scp the .onnx file to
BlackWidow at /home/alex/observability-lgtm/edge-ai/models/.
"""

import argparse
import json
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import requests
from sklearn.ensemble import IsolationForest
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

FEATURES_JSON = Path(__file__).parent.parent / "features.json"

# Members to include in training (servers only — locators have a different profile)
TRAIN_MEMBERS = ["server1", "server2"]


def parse_args():
    p = argparse.ArgumentParser(description="Train Geode anomaly detection ONNX model")
    p.add_argument("--mimir-url", default="http://192.168.0.153:9009/prometheus",
                   help="Mimir Prometheus API base URL")
    p.add_argument("--output-dir", default="models",
                   help="Directory to write geode_anomaly.onnx")
    p.add_argument("--lookback-hours", type=int, default=24,
                   help="Hours of historical data to use for training")
    p.add_argument("--step", type=int, default=60,
                   help="Query step in seconds (1 data point per step)")
    p.add_argument("--contamination", type=float, default=0.05,
                   help="IsolationForest contamination fraction")
    return p.parse_args()


def query_range(mimir_url: str, promql: str, start: int, end: int, step: int) -> pd.Series:
    """Query Mimir query_range. Returns a Series indexed by timestamp, values are floats.
    Raises on HTTP error or empty result."""
    url = f"{mimir_url}/api/v1/query_range"
    params = {"query": promql, "start": start, "end": end, "step": step}
    r = requests.get(url, params=params, timeout=30)
    r.raise_for_status()
    data = r.json()
    if data["status"] != "success":
        raise ValueError(f"Mimir query failed: {data}")
    results = data["data"]["result"]
    if not results:
        return pd.Series(dtype=float)
    # Merge all series (e.g. after sum by member, there should be one per member)
    frames = []
    for series in results:
        vals = pd.Series(
            {int(v[0]): float(v[1]) for v in series["values"]},
            dtype=float,
        )
        frames.append(vals)
    combined = pd.concat(frames).groupby(level=0).mean()
    return combined.sort_index()


def compute_rate(series: pd.Series, step: int) -> pd.Series:
    """Compute per-second rate from a monotonic counter series."""
    return series.diff() / step


def build_feature_matrix(mimir_url: str, member: str, instance: str,
                          start: int, end: int, step: int,
                          features: list) -> pd.DataFrame:
    """Fetch all raw metrics for one member and build the 10-column feature DataFrame."""
    label_filter = f'job="geode", member="{member}"'
    columns = {}

    for feat in features:
        name = feat["name"]
        derived = feat["derived"]

        if derived == "ratio":
            num_q = f'{feat["numerator_metric"]}{{area="{feat["extra_labels"]["area"]}", {label_filter}}}'
            den_q = f'{feat["denominator_metric"]}{{area="{feat["extra_labels"]["area"]}", {label_filter}}}'
            num = query_range(mimir_url, num_q, start, end, step)
            den = query_range(mimir_url, den_q, start, end, step)
            if num.empty or den.empty:
                print(f"  WARNING: no data for {name} on {member}, filling with 0")
                idx = num.index if not num.empty else den.index
                columns[name] = pd.Series(0.0, index=idx)
            else:
                aligned_num, aligned_den = num.align(den, join="inner")
                columns[name] = aligned_num / aligned_den.replace(0, np.nan)

        elif derived == "rate":
            if feat.get("sum_by_member"):
                q = f'sum by (member) ({feat["metric"]}{{job="geode", member="{member}"}})'
            else:
                q = f'{feat["metric"]}{{job="geode", member="{member}"}}'
            raw = query_range(mimir_url, q, start, end, step)
            if raw.empty:
                print(f"  WARNING: no data for {name} on {member}, filling with 0")
                columns[name] = pd.Series(dtype=float)
            else:
                columns[name] = compute_rate(raw, step).clip(lower=0)

        else:  # raw
            q = f'{feat["metric"]}{{job="geode", member="{member}"}}'
            raw = query_range(mimir_url, q, start, end, step)
            if raw.empty:
                print(f"  WARNING: no data for {name} on {member}, filling with 0")
                columns[name] = pd.Series(dtype=float)
            else:
                columns[name] = raw

    df = pd.DataFrame(columns)
    df = df.dropna()
    return df


def main():
    args = parse_args()
    features = json.loads(FEATURES_JSON.read_text())
    features = sorted(features, key=lambda f: f["index"])
    feature_names = [f["name"] for f in features]
    n_features = len(features)

    end = int(time.time())
    start = end - args.lookback_hours * 3600
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Querying Mimir at {args.mimir_url}")
    print(f"Window: {args.lookback_hours}h ({start} → {end}), step={args.step}s")
    print(f"Members: {TRAIN_MEMBERS}")
    print()

    all_frames = []
    for member in TRAIN_MEMBERS:
        print(f"Fetching features for {member}...")
        df = build_feature_matrix(
            args.mimir_url, member, member, start, end, args.step, features
        )
        if df.empty:
            print(f"  SKIP: no data returned for {member}")
            continue
        sparsity = df.isnull().mean().mean()
        if sparsity > 0.20:
            print(f"  WARNING: {member} data is {sparsity:.0%} sparse — model accuracy may be reduced")
        df = df.fillna(0.0)
        print(f"  {len(df)} rows, {n_features} features")
        all_frames.append(df[feature_names])

    if not all_frames:
        print("ERROR: No training data fetched. Ensure Geode has been running and metrics are in Mimir.")
        sys.exit(1)

    X = np.vstack([f.values for f in all_frames]).astype(np.float32)
    print(f"\nTraining matrix: {X.shape[0]} rows × {X.shape[1]} features")

    pipeline = Pipeline([
        ("scaler", StandardScaler()),
        ("model", IsolationForest(
            n_estimators=100,
            contamination=args.contamination,
            max_samples="auto",
            random_state=42,
        )),
    ])
    print("Fitting IsolationForest pipeline...")
    pipeline.fit(X)

    scores = pipeline.decision_function(X)
    print(f"\nScore distribution (decision_function on training data):")
    print(f"  min={scores.min():.4f}  5th%={np.percentile(scores, 5):.4f}  "
          f"mean={scores.mean():.4f}  95th%={np.percentile(scores, 95):.4f}  max={scores.max():.4f}")
    print(f"  Suggested alert threshold: {np.percentile(scores, 5):.4f} "
          f"(5th percentile of training data)")

    # Export to ONNX
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType

    # onnx 1.16+ rejects Python bool in ints fields; skl2onnx 1.17 passes booleans
    # for nodes_missing_value_tracks_true. Cast them to int before attribute creation.
    import onnx.helper as _onnx_helper
    _orig_make_attribute = _onnx_helper.make_attribute
    def _make_attribute_bool_safe(key, value, doc_string=None, attr_type=None):
        if isinstance(value, (list, tuple)):
            value = [int(v) if isinstance(v, bool) else v for v in value]
        return _orig_make_attribute(key, value, doc_string=doc_string, attr_type=attr_type)
    _onnx_helper.make_attribute = _make_attribute_bool_safe

    model_proto = convert_sklearn(
        pipeline,
        initial_types=[("float_input", FloatTensorType([None, n_features]))],
        target_opset={"": 15, "ai.onnx.ml": 3},
    )
    onnx_path = output_dir / "geode_anomaly.onnx"
    onnx_path.write_bytes(model_proto.SerializeToString())
    print(f"\nModel saved to: {onnx_path}")

    # Quick validation (optional — requires onnxruntime)
    try:
        import onnxruntime as rt
        sess = rt.InferenceSession(str(onnx_path))
        dummy = np.zeros((1, n_features), dtype=np.float32)
        out = sess.run(None, {"float_input": dummy})
        print(f"ONNX validation: input shape {dummy.shape} → score {float(np.array(out[1]).ravel()[0]):.4f}")
    except ModuleNotFoundError:
        print("onnxruntime not installed — skipping validation (model file is still valid)")
        print("  To validate: pip install onnxruntime && python training\\train.py --validate-only")
    print("\nDone. Copy geode_anomaly.onnx to BlackWidow:")
    print("  scp models/geode_anomaly.onnx alex@192.168.0.153:/home/alex/observability-lgtm/edge-ai/models/")


if __name__ == "__main__":
    main()
