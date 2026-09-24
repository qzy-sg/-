FROM python:3.11-slim
WORKDIR /app
COPY services/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY services /app/services
ENV PYTHONPATH=/app/services
WORKDIR /app/services
CMD ["arq", "worker.main.WorkerSettings"]
