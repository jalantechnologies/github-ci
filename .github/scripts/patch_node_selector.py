import os
import yaml

# Get environment variables
hosting_provider = os.getenv('hosting_provider', '').lower()
app_env = os.getenv('app_env', '').lower()

# Read appropriate key and value
if hosting_provider == 'aws':
    key = os.getenv('NODE_SELECTOR_KEY_AWS')
    value = os.getenv('NODE_SELECTOR_VALUE_AWS')
elif hosting_provider == 'digital_ocean':
    key = os.getenv('NODE_SELECTOR_KEY_DO')
    value = os.getenv('NODE_SELECTOR_VALUE_DO')
else:
    raise ValueError(f"Unsupported hosting provider: {hosting_provider}")

# Target file
path = f"lib/kube/{app_env}/deployment.yaml"

with open(path) as f:
    docs = list(yaml.safe_load_all(f))

# Find the deployment document
for doc in docs:
    if doc.get("kind") == "Deployment":
        doc["spec"]["template"]["spec"]["affinity"]["nodeAffinity"]["requiredDuringSchedulingIgnoredDuringExecution"]["nodeSelectorTerms"][0]["matchExpressions"][0] = {
            "key": key,
            "operator": "In",
            "values": [value]
        }

with open(path, 'w') as f:
    yaml.dump_all(docs, f, sort_keys=False)

print(f"✅ Patched {path} with key={key} and value={value}")
