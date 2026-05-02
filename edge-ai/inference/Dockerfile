FROM python:3.11-slim AS builder
WORKDIR /build
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim AS runtime
COPY --from=builder /opt/venv /opt/venv
WORKDIR /app
COPY app/ ./app/
ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 9500
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "9500"]
