FROM python:3.11-slim

# Create non-root user
RUN useradd -m -u 1000 -s /bin/bash exporter

WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the exporter script
COPY exporter.py .

# Change ownership of the app directory
RUN chown -R exporter:exporter /app

# Switch to non-root user
USER exporter

# Expose the metrics port
EXPOSE 9100

# Set default environment variables
ENV EXPORTER_PORT=9100
ENV SCRAPE_INTERVAL=60
ENV PYTHONUNBUFFERED=1

# Run the exporter
CMD ["python", "-u", "exporter.py"]
