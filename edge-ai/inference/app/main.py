import asyncio
import logging
import time
from contextlib import asynccontextmanager

from fastapi import FastAPI, Response
from prometheus_client import CONTENT_TYPE_LATEST, generate_latest

from .metrics import anomaly_score, inference_errors, last_inference_ts
from .mimir import build_feature_vector
from .model import AnomalyModel
from .settings import Settings

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
logger = logging.getLogger(__name__)

settings = Settings()
model = AnomalyModel(settings.model_path)
_members = settings.parsed_members()  # list of (member, instance) tuples


async def _inference_loop():
    logger.info("Inference loop starting — poll interval %ds, lookback %dm",
                settings.poll_interval, settings.lookback_minutes)
    while True:
        for member, instance in _members:
            try:
                vec = await build_feature_vector(
                    settings.mimir_url, member, settings.lookback_minutes
                )
                if vec is None:
                    inference_errors.labels(member=member, reason="no_data").inc()
                    logger.warning("No feature data for %s", member)
                    continue
                score = model.score(vec)
                anomaly_score.labels(instance=instance, member=member).set(score)
                last_inference_ts.labels(member=member).set(time.time())
                logger.debug("member=%s instance=%s score=%.4f", member, instance, score)
            except Exception as exc:
                inference_errors.labels(member=member, reason="error").inc()
                logger.error("Inference failed for %s: %s", member, exc)
        await asyncio.sleep(settings.poll_interval)


@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(_inference_loop())
    yield
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass


app = FastAPI(title="Geode AI Anomaly Detection", lifespan=lifespan)


@app.get("/metrics")
def metrics():
    return Response(content=generate_latest(), media_type=CONTENT_TYPE_LATEST)


@app.get("/health")
def health():
    now = time.time()
    member_ages = {}
    stale = False
    for member, _ in _members:
        ts_gauge = last_inference_ts.labels(member=member)
        last_ts = ts_gauge._value.get()  # prometheus_client internal — float or 0
        age = now - last_ts if last_ts > 0 else None
        member_ages[member] = round(age, 1) if age is not None else None
        if age is None or age > settings.poll_interval * 3:
            stale = True

    status = "ok" if (model.loaded and not stale) else "degraded"
    body = {
        "status": status,
        "model_loaded": model.loaded,
        "members": [m for m, _ in _members],
        "last_inference_age_seconds": member_ages,
    }

    from fastapi.responses import JSONResponse
    return JSONResponse(content=body, status_code=200 if status == "ok" else 503)
