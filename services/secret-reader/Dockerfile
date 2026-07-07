FROM python:3.12-slim

WORKDIR /app

RUN pip install boto3 --no-cache-dir

COPY app.py .

RUN useradd --no-create-home --shell /bin/false --uid 1001 appuser && \
    chown -R appuser:appuser /app

USER 1001

EXPOSE 8080

CMD ["python", "app.py"]
