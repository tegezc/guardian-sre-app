#!/bin/bash

# ==============================================================================
# The Guardian SRE - Automated Cloud Run Deployment Script
# ==============================================================================
# This script automates the deployment of the Python backend to Google Cloud Run.
# It fulfills the "Automated Cloud Deployment" hackathon bonus requirement.

# Exit immediately if a command exits with a non-zero status
set -e

# Configuration Variables
PROJECT_ID="hackathon-460016"
SERVICE_NAME="guardian-sre-backend"
REGION="asia-southeast2"

echo "===================================================="
echo "🚀 Starting automated deployment for $SERVICE_NAME..."
echo "📍 Target Region: $REGION"
echo "📁 Project ID: $PROJECT_ID"
echo "===================================================="

# Verify gcloud is installed
if ! command -v gcloud &> /dev/null
then
    echo "❌ ERROR: gcloud CLI could not be found. Please install Google Cloud SDK."
    exit 1
fi

# Set the target project
gcloud config set project $PROJECT_ID

# Deploy to Cloud Run using source deployment
echo "☁️  Packaging and deploying to Google Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --source . \
  --port 8080 \
  --region $REGION \
  --allow-unauthenticated \
  --quiet

echo "===================================================="
echo "✅ Deployment successful! The Guardian SRE backend is now LIVE."
echo "===================================================="