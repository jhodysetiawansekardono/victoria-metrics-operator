#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

# Generate list.txt with "<node_name> <internal_ip>" per line.
# Uses `-o json` + jq instead of `-o wide` + awk column index: the wide
# output's column layout (and therefore which column is the internal IP)
# is not guaranteed stable across kubectl/cluster versions.
kubectl get nodes -o json \
  | jq -r '.items[] | [.metadata.name, (.status.addresses[] | select(.type=="InternalIP") | .address)] | @tsv' \
  > list.txt
echo "Generated list.txt"

known_nodes=()

while read -r node_name node_ip; do
  node_name=$(echo "$node_name" | tr -d '[:space:]')
  node_ip=$(echo "$node_ip" | tr -d '[:space:]')
  known_nodes+=("$node_name")

  cp template.yaml.tpl "${node_name}.yaml"
  sed -i "s/NODE_NAME/$node_name/g" "${node_name}.yaml"
  sed -i "s/NODE_IP/$node_ip/g" "${node_name}.yaml"
  echo "Generated ${node_name}.yaml"
done < list.txt

# Cleanup: remove generated manifests for nodes that no longer exist in the
# cluster, so deleted nodes don't leave orphaned VMProbe objects behind.
# template.yaml.tpl doesn't match this *.yaml glob, so it's untouched.
for f in *.yaml; do
  base="${f%.yaml}"
  found=0
  for n in "${known_nodes[@]:-}"; do
    [ "$n" = "$base" ] && found=1 && break
  done
  if [ "$found" -eq 0 ]; then
    rm -f "$f"
    echo "Removed stale ${f} (node no longer in cluster)"
  fi
done

echo ""
echo "Review the generated files, then apply with:"
echo "  kubectl apply -f vmprobe/"
echo "If any node was removed above, also run:"
echo "  kubectl -n monitoring-system delete vmprobe blackbox-<removed-node-name>"
