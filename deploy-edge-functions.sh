#!/bin/bash

#  deploy-edge-functions.sh
#  Created automatically by Cursor Assistant
#  Created on: 2025-01-22 at 22:15 (America/Los_Angeles - Pacific Time)
#  Notes: Script to deploy Supabase Edge Functions

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project directory
PROJECT_DIR="/Users/timrobinson/Developer/TastyMangoes"
PROJECT_REF="zyywpjddzvkqvjosifiy"

# Change to project directory
cd "$PROJECT_DIR"

echo -e "${GREEN}🚀 Supabase Edge Functions Deployment Script${NC}"
echo ""

# Check if supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo -e "${RED}❌ Error: Supabase CLI is not installed${NC}"
    echo "Install it with: npm install -g supabase"
    exit 1
fi

# Function to deploy a single edge function
deploy_function() {
    local function_name=$1
    echo -e "${YELLOW}📦 Deploying ${function_name}...${NC}"
    
    if supabase functions deploy "$function_name"; then
        echo -e "${GREEN}✅ Successfully deployed ${function_name}${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Failed to deploy ${function_name}${NC}"
        echo ""
        return 1
    fi
}

# Check if a specific function name was provided
if [ $# -eq 0 ]; then
    # No arguments - show menu
    echo "Available edge functions:"
    echo "  1) search-movies"
    echo "  2) ingest-movie"
    echo "  3) get-movie-card"
    echo "  4) get-similar-movies"
    echo "  5) scheduled-ingest"
    echo "  6) batch-ingest"
    echo "  7) log-voice-event"
    echo "  8) capture-google-streaming"
    echo "  9) all (deploy all functions)"
    echo ""
    echo "Usage: ./deploy-edge-functions.sh [function-name]"
    echo "Example: ./deploy-edge-functions.sh search-movies"
    echo "Example: ./deploy-edge-functions.sh all"
    exit 0
fi

FUNCTION_NAME=$1

if [ "$FUNCTION_NAME" == "all" ]; then
    # Deploy all functions
    echo -e "${YELLOW}📦 Deploying all edge functions...${NC}"
    echo ""
    
    FUNCTIONS=(
        "search-movies"
        "ingest-movie"
        "get-movie-card"
        "get-similar-movies"
        "scheduled-ingest"
        "batch-ingest"
        "log-voice-event"
        "capture-google-streaming"
    )
    
    FAILED=()
    
    for func in "${FUNCTIONS[@]}"; do
        if ! deploy_function "$func"; then
            FAILED+=("$func")
        fi
    done
    
    echo ""
    if [ ${#FAILED[@]} -eq 0 ]; then
        echo -e "${GREEN}✅ All functions deployed successfully!${NC}"
        echo ""
        echo "View deployments: https://supabase.com/dashboard/project/${PROJECT_REF}/functions"
    else
        echo -e "${RED}❌ Some functions failed to deploy:${NC}"
        for func in "${FAILED[@]}"; do
            echo -e "  - ${RED}${func}${NC}"
        done
        exit 1
    fi
else
    # Deploy single function
    deploy_function "$FUNCTION_NAME"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}🎉 Deployment complete!${NC}"
        echo ""
        echo "View deployment: https://supabase.com/dashboard/project/${PROJECT_REF}/functions/${FUNCTION_NAME}"
    else
        exit 1
    fi
fi

