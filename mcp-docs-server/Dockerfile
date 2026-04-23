FROM python:3.11-slim

# Install system dependencies for Playwright
RUN apt-get update && apt-get install -y \
    libgbm-dev libnss3 libasound2 wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN playwright install chromium
RUN playwright install-deps chromium

COPY . .

# Expose the HTTP port
EXPOSE 8000

# Start the server (no longer using stdio)
ENTRYPOINT ["python", "server.py"]
