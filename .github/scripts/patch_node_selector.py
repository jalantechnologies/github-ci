import os
import yaml

def patch_node_selector(file_path, provider):
    with open(file_path) as f:
        docs = list(yaml.safe_load_all(f))

    for doc in docs:
        if doc.get('kind') != 'Deployment':
            continue
        containers = doc['spec']['template']['spec']
        node_affinity = containers.setdefault('affinity', {}).setdefault('nodeAffinity', {}).setdefault(
            'requiredDuringSchedulingIgnoredDuringExecution', {}
        ).setdefault('nodeSelectorTerms', [{}]).setdefault('matchExpressions', [])

        # Remove existing nodeSelectorTerms (optional: clean slate)
        node_affinity.clear()

        if provider == "AWS":
            expression = {
                'key': 'kubernetes.githubci.com/nodegroup',
                'operator': 'In',
                'values': ['ng-preview-pool']  # or production version
            }
        elif provider == "DIGITAL_OCEAN":
            expression = {
                'key': 'doks.digitalocean.com/node-pool',
                'operator': 'In',
                'values': ['platform-cluster-01-preview-pool']  # or production version
            }
        else:
            raise ValueError(f"Unknown provider: {provider}")

        containers['affinity']['nodeAffinity']['requiredDuringSchedulingIgnoredDuringExecution']['nodeSelectorTerms'] = [
            {
                'matchExpressions': [expression]
            }
        ]

    with open(file_path, 'w') as f:
        yaml.safe_dump_all(docs, f, default_flow_style=False)

if __name__ == "__main__":
    provider = os.getenv("hosting_provider", "DIGITAL_OCEAN")
    env = os.getenv("app_env", "preview")  # e.g., preview or production
    file_path = f"lib/kube/{env}/deployment.yaml"

    patch_node_selector(file_path, provider)
