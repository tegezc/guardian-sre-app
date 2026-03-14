# Use lightweight Python image
FROM python:3.11-slim

# Set working directory inside container
WORKDIR /app

# Copy requirements file and install
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy entire backend source code
COPY . .

# Tell Cloud Run which port is used
ENV PORT=8080

# Run the application
CMD ["python", "app.py"]