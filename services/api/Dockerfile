FROM python:3.11-slim
WORKDIR /app
COPY services/requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt
COPY services /app/services
COPY webview-vr /app/webview-vr
ENV PYTHONPATH=/app/services
WORKDIR /app/services
EXPOSE 8000
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
