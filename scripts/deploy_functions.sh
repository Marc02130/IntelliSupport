#!/bin/bash

# Array of function names
FUNCTIONS=(
  "api-edit-message"
  "api-preview-message"
  "api-search-table"
  "api-send-message"
  "batch-message-cancel"
  "batch-message-generator"
  "batch-message-history"
  "batch-message-retry"
  "batch-message-status"
  "batch-messages"
  "feedback-analysis"
  "generate-message"
  "message-feedback"
  "preview-message"
  "preview-message-batch"
  "preview-message-realtime"
  "process-embedding-queue"
  "process-embeddings"
  "process-scheduled-messages"
  "route-ticket"
  "route-tickets-job"
)

# Project reference
PROJECT_REF="ntlxuoqhpzckyvzpmicn"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Error counter
ERRORS=0

# Parse command line arguments
LOCAL_DEPLOY=false
while getopts "l" opt; do
  case $opt in
    l)
      LOCAL_DEPLOY=true
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
  esac
done

# Cleanup function for Docker
cleanup_docker() {
  echo "Cleaning up Docker containers..."
  # Stop and remove the edge runtime container if it exists
  docker ps -q --filter "name=supabase_edge_runtime_*" | xargs -r docker stop
  docker ps -aq --filter "name=supabase_edge_runtime_*" | xargs -r docker rm
  echo "Docker cleanup complete"
}

# Deploy a single function
deploy_function() {
  local func=$1
  echo -e "${YELLOW}Deploying $func...${NC}"

  if [ "$LOCAL_DEPLOY" = true ]; then
    # Copy local env file if it exists
    if [ -f "./supabase/functions/_shared/.env.local" ]; then
      yes | cp -f ./supabase/functions/_shared/.env.local ./supabase/functions/$func/.env
    else
      # Fall back to regular .env if .env.local doesn't exist
      yes | cp -f ./supabase/functions/_shared/.env ./supabase/functions/$func/.env
    fi
  else
    # Production deployment - use regular .env
    yes | cp -f ./supabase/functions/_shared/.env ./supabase/functions/$func/.env
  fi

  # Check if .env file exists
  if [ ! -f "./supabase/functions/$func/.env" ]; then
    echo -e "${YELLOW}Warning: No .env file found for $func${NC}"
  fi
  
  if [ "$LOCAL_DEPLOY" = true ]; then
    # Local deployment
    echo "Starting local deployment for $func..."
    
    # Create unique container name for this function
    local container_name="supabase_edge_runtime_${func}"
    
    # Stop and remove existing container if it exists
    docker ps -q --filter "name=$container_name" | xargs -r docker stop
    docker ps -aq --filter "name=$container_name" | xargs -r docker rm
    
    # Start function with unique container name
    if DOCKER_CONTAINER_NAME=$container_name npx supabase functions serve $func --no-verify-jwt --env-file ./supabase/functions/$func/.env &> "/tmp/supabase-$func.log" & then
      echo $! > "/tmp/supabase-$func.pid"
      # Wait a moment to check if the process stays alive
      sleep 2
      if kill -0 $(cat "/tmp/supabase-$func.pid") 2>/dev/null; then
        echo -e "${GREEN}$func started locally${NC}"
      else
        echo -e "${RED}Failed to start $func locally${NC}"
        cat "/tmp/supabase-$func.log"
        ERRORS=$((ERRORS + 1))
      fi
    else
      echo -e "${RED}Failed to start $func locally${NC}"
      cat "/tmp/supabase-$func.log"
      ERRORS=$((ERRORS + 1))
    fi
  else
    # Production deployment
    # Set environment variables
    if npx supabase secrets set --env-file ./supabase/functions/$func/.env 2>/dev/null; then
      echo "Environment variables set"
    else
      echo -e "${YELLOW}Warning: Failed to set environment variables for $func${NC}"
    fi
    
    # Add function-specific environment variables if needed
    if [ "$func" = "preview-message-realtime" ]; then
      echo "Verifying Redis connection..."
      if curl -s "$REDIS_HOST:$REDIS_PORT" > /dev/null; then
        echo -e "${GREEN}Redis connection verified${NC}"
      else
        echo -e "${YELLOW}Warning: Could not verify Redis connection${NC}"
      fi
    fi
    
    # Deploy function
    if npx supabase functions deploy $func --project-ref $PROJECT_REF; then
      echo -e "${GREEN}$func deployed successfully${NC}"
      
      # Verify deployment
      sleep 2 # Wait for deployment to propagate
      if curl -s "https://$PROJECT_REF.supabase.co/functions/v1/$func" -I | grep -q "200\|404"; then
        echo -e "${GREEN}$func deployment verified${NC}"
      else
        echo -e "${RED}Warning: Could not verify $func deployment${NC}"
        ERRORS=$((ERRORS + 1))
      fi
    else
      echo -e "${RED}Failed to deploy $func${NC}"
      ERRORS=$((ERRORS + 1))
    fi
  fi
  
  echo "-------------------"
}

# Add this before the main deployment loop
if [ "$LOCAL_DEPLOY" = true ]; then
  cleanup_docker
fi

# Main deployment loop
for func in "${FUNCTIONS[@]}"
do
  deploy_function "$func"
done

# Final status
if [ $ERRORS -eq 0 ]; then
  if [ "$LOCAL_DEPLOY" = true ]; then
    echo -e "${GREEN}All functions started locally!${NC}"
    echo "Press Ctrl+C to stop all functions"
    # Wait indefinitely
    while true; do sleep 1; done
  else
    echo -e "${GREEN}All functions deployed successfully!${NC}"
  fi
  exit 0
else
  echo -e "${RED}Deployment completed with $ERRORS errors${NC}"
  exit 1
fi 