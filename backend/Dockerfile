ARG PYTHON_VERSION=3.13

FROM python:${PYTHON_VERSION}-alpine AS builder

WORKDIR /app

# Install build dependencies (including postgresql-dev for psycopg2)
RUN apk add --no-cache gcc musl-dev libffi-dev postgresql-dev

# Create virtualenv and install dependencies
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

FROM python:${PYTHON_VERSION}-alpine

WORKDIR /app

# Install runtime dependencies for psycopg2
RUN apk add --no-cache libpq

# Copy virtualenv from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set environment variables
ARG APP_VERSION=latest
ENV PYTHONUNBUFFERED=1
ENV APP_VERSION=${APP_VERSION}

# Create non-root user
RUN adduser -D -u 1000 appuser

# Copy application
COPY --chown=appuser:appuser . .

USER appuser

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/api/health')" || exit 1

# Run the application
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
