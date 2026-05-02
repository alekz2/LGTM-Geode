import logging
from pathlib import Path

import numpy as np
import onnxruntime as rt

logger = logging.getLogger(__name__)

N_FEATURES = 10
INPUT_NAME = "float_input"


class AnomalyModel:
    def __init__(self, model_path: str):
        self._path = Path(model_path)
        self._session: rt.InferenceSession | None = None
        self._load()

    def _load(self):
        if not self._path.exists():
            logger.error("Model file not found: %s — running in degraded mode", self._path)
            return
        try:
            self._session = rt.InferenceSession(str(self._path))
            logger.info("ONNX model loaded from %s", self._path)
        except Exception as exc:
            logger.error("Failed to load ONNX model: %s", exc)
            self._session = None

    @property
    def loaded(self) -> bool:
        return self._session is not None

    def score(self, feature_vec: list[float]) -> float:
        """Run inference on a single feature vector. Returns the decision_function score."""
        if not self.loaded:
            raise RuntimeError("Model not loaded")
        if len(feature_vec) != N_FEATURES:
            raise ValueError(f"Expected {N_FEATURES} features, got {len(feature_vec)}")
        x = np.array([feature_vec], dtype=np.float32)
        outputs = self._session.run(None, {INPUT_NAME: x})
        # outputs[0] = label (-1/+1), outputs[1] = scores array shape (1,)
        return float(outputs[1][0])
