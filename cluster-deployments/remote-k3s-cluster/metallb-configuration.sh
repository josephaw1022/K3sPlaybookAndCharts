

#!/bin/bash

set -e

kubectx default 

echo "Creating MetalLB IPAddressPool and L2Advertisement..."

kubectl apply -f - <<EOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-pool
  namespace: metallb-system
spec:
  addresses:
    - 192.168.2.60-192.168.2.80
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: metallb-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - metallb-pool
EOF

echo "MetalLB configuration applied successfully."
