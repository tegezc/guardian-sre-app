# Gunakan image Python yang ringan
FROM python:3.11-slim

# Set working directory di dalam container
WORKDIR /app

# Copy file requirements dan install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy seluruh source code backend
COPY . .

# Beritahu Cloud Run port berapa yang digunakan
ENV PORT=8080

# Jalankan aplikasi
CMD ["python", "app.py"]