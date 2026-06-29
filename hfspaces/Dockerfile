FROM python:3.13-slim

WORKDIR /app

# System dependencies
RUN apt-get update && apt-get install -y \
    libgl1-mesa-glx libglib2.0-0 \
    tesseract-ocr tesseract-ocr-eng \
    ffmpeg supervisor git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir --upgrade pip

# Clone the Navigwiz repo
RUN git clone --depth=1 https://github.com/hritesh023/Navigwiz.git /repo

# Install Python dependencies
RUN pip install --no-cache-dir \
    fastapi uvicorn[standard] \
    pydantic pydantic-settings python-multipart \
    httpx websockets \
    "python-jose[cryptography]" "passlib[bcrypt]" supabase \
    chromadb faiss-cpu sentence-transformers numpy networkx \
    langchain langchain-openai langchain-community langgraph openai \
    beautifulsoup4 duckduckgo_search \
    PyMuPDF python-docx openpyxl pandas \
    Pillow pytesseract \
    celery redis apscheduler \
    cloudinary boto3 aiofiles \
    prometheus-client sentry-sdk \
    python-dotenv

# Pre-download ML model
RUN python -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('all-MiniLM-L6-v2')" 2>/dev/null || true

# Link backend code
RUN cp -r /repo/backend/* /app/ && \
    mkdir -p /app/data/chroma /app/data/faiss /app/data/memory /app/data/uploads

# HF Spaces default port
ENV PORT=7860
EXPOSE 7860

# Supervisor config (inline to avoid file dependency)
RUN echo "[supervisord]\nnodaemon=true\nuser=root\nlogfile=/tmp/supervisord.log\nloglevel=info\n\n[program:api]\ncommand=uvicorn app.main:app --host 0.0.0.0 --port 7860\ndirectory=/app\nautostart=true\nautorestart=true\nstdout_logfile=/tmp/api.log\nstderr_logfile=/tmp/api.err.log\n\n[program:worker]\ncommand=celery -A app.workers.celery_app worker --loglevel=info --concurrency=1\ndirectory=/app\nautostart=true\nautorestart=true\nstdout_logfile=/tmp/worker.log\nstderr_logfile=/tmp/worker.err.log" > /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
