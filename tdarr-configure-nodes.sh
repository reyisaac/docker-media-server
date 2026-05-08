#!/bin/bash
# Waits for all 3 Tdarr nodes to register then sets 3 GPU workers on each

TDARR_URL="http://localhost:8265"
EXPECTED_NODES=3
MAX_WAIT=120

echo "Waiting for $EXPECTED_NODES Tdarr nodes to connect..."

for i in $(seq 1 $MAX_WAIT); do
  NODE_COUNT=$(curl -s "$TDARR_URL/api/v2/get-nodes" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null)
  if [ "$NODE_COUNT" -ge "$EXPECTED_NODES" ] 2>/dev/null; then
    echo "All $NODE_COUNT nodes connected."
    break
  fi
  sleep 2
done

if [ "$NODE_COUNT" -lt "$EXPECTED_NODES" ] 2>/dev/null; then
  echo "Warning: only $NODE_COUNT nodes connected after ${MAX_WAIT}s, applying settings anyway."
fi

# Set 3 GPU workers on every node
curl -s "$TDARR_URL/api/v2/get-nodes" | python3 -c "
import json, sys, urllib.request

nodes = json.load(sys.stdin)
for node_id, node in nodes.items():
    name = node['nodeName']
    payload = json.dumps({
        'data': {
            'nodeID': node_id,
            'nodeUpdates': {
                'workerLimits': {
                    'healthcheckcpu': 0,
                    'healthcheckgpu': 0,
                    'transcodecpu': 0,
                    'transcodegpu': 3
                }
            }
        }
    }).encode()
    req = urllib.request.Request(
        'http://localhost:8265/api/v2/update-node',
        data=payload,
        headers={'Content-Type': 'application/json'},
        method='POST'
    )
    resp = urllib.request.urlopen(req).read().decode()
    print(f'{name} ({node_id}): {resp}')
"

echo "Done."
