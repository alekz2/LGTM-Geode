from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    mimir_url: str = "http://mimir:9009/prometheus"
    model_path: str = "/models/geode_anomaly.onnx"
    poll_interval: int = 60
    lookback_minutes: int = 5
    # Comma-separated member:instance pairs, e.g. "server1:antman,server2:hulk"
    members: str = "server1:antman,server2:hulk"
    metrics_port: int = 9500

    model_config = {"env_prefix": "GEODE_AI_"}

    def parsed_members(self) -> list[tuple[str, str]]:
        pairs = []
        for token in self.members.split(","):
            token = token.strip()
            if ":" not in token:
                raise ValueError(f"GEODE_AI_MEMBERS entry must be 'member:instance', got: {token!r}")
            member, instance = token.split(":", 1)
            pairs.append((member.strip(), instance.strip()))
        return pairs
