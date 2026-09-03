# Slide 6-8 (Module 1, deck 01): image build for ACR Tasks
FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Deliberately non-default port to force a live WEBSITES_PORT demo
# (Slide 17, deck 01: "Set WEBSITES_PORT if container listens on a
# port other than 80 or 8080")
EXPOSE 8000
ENV PORT=8000

# Startup command in the image (Dockerfile CMD). During the demo you can
# override this at the App Service level with a custom Startup Command
# to show "Startup command overrides Dockerfile CMD, not ENTRYPOINT".
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "app:app"]
