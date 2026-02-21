#!/bin/bash

# Douluo Bridge - GitHub Action Monitor (JQ Version)
# Usage: ./scripts/monitor_release.sh [tag]

TAG=$1
REPO="pemagic/DouluoBridge"

if [ -z "$TAG" ]; then
    echo "Usage: $0 [tag]"
    echo "Example: $0 v1.8.1"
    exit 1
fi

echo "🔍 Monitoring GitHub Action for tag: $TAG using Public API + JQ..."

while true; do
    # Get the latest workflow runs
    RESPONSE=$(curl -s "https://api.github.com/repos/$REPO/actions/runs?per_page=10")
    
    # Use JQ to find the run corresponding to the target tag/branch (head_branch should match tag for push tags)
    # We look for head_branch matching the tag OR head_sha (if we wanted to be even more precise)
    RUN=$(echo "$RESPONSE" | jq -r ".workflow_runs[] | select(.head_branch == \"$TAG\") | {status: .status, conclusion: .conclusion, html_url: .html_url}")
    
    if [ -z "$RUN" ] || [ "$RUN" == "null" ]; then
        echo "⏳ Workflow not found yet for $TAG. Retrying in 20s..."
    else
        STATUS=$(echo "$RUN" | jq -r .status)
        CONCLUSION=$(echo "$RUN" | jq -r .conclusion)
        URL=$(echo "$RUN" | jq -r .html_url)
        
        echo "🕒 [$(date +%H:%M:%S)] Status: $STATUS | Conclusion: $CONCLUSION"
        
        if [ "$STATUS" == "completed" ]; then
            if [ "$CONCLUSION" == "success" ]; then
                echo "✅ Workflow SUCCESS!"
                echo "🔗 View Release Assets: https://github.com/$REPO/releases"
                exit 0
            else
                echo "❌ Workflow FAILED! Check logs at: $URL"
                exit 1
            fi
        fi
    fi
    sleep 30
done
