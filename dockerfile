FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir --default-timeout=100 --retries 5 -r requirements.txt

COPY . .

EXPOSE 5000

RUN addgroup --system appgroup && adduser --system --ingroup appgroup appuser

# Switch to that user for the CMD
USER appuser

CMD ["python", "app.py"]

