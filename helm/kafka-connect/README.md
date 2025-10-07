# Kafka Connect Helm Chart

This Helm chart deploys Kafka Connect with a modular design that separates the Connect cluster deployment from connector management.

## Chart Structure

```
helm/kafka-connect/
├── Chart.yaml                    # Main chart with connectors dependency
├── values.yaml                   # Default values
├── values-*.yaml                 # Environment-specific values
├── templates/
│   ├── _helpers.tpl              # Helper templates
│   ├── deployment.yaml           # Kafka Connect cluster
│   ├── service.yaml              # Connect service
│   └── serviceaccount.yaml       # RBAC
└── charts/
    └── connectors/               # Connectors subchart
        ├── Chart.yaml
        ├── values.yaml
        ├── templates/
        │   ├── _helpers.tpl
        │   ├── configmap.yaml    # Connector configurations
        │   └── job-reconcile.yaml # Helm hook job
```

## Features

### Main Chart (`kafka-connect`)
- Deploys Kafka Connect cluster (Deployment, Service, ServiceAccount)
- Configurable scaling and resource management
- Health checks and monitoring
- Global values for cross-chart configuration

### Connectors Subchart (`connectors`)
- Independent connector lifecycle management
- Helm hook-based reconciliation (`post-install`, `post-upgrade`)
- Environment-specific connector configurations
- Pruning support for production environments
- Enhanced error handling and logging

## Configuration Flags

### Reconcile Configuration
```yaml
connectors:
  reconcile:
    enabled: true        # Enable connector reconciliation
    prune: false        # Delete connectors not in config
  legacy:
    reconcileEnabled: false  # Legacy reconcile mode (disabled)
```

### Global Values
```yaml
global:
  connect:
    restUrl: ""         # Connect REST URL (auto-computed)
    namespace: ""       # Target namespace (auto-computed)
    timeout: 300        # REST API timeout
    pollInterval: 5     # REST API poll interval
```

## Environment-Specific Deployments

### Development
```bash
helm install kafka-connect helm/kafka-connect \
  --values helm/kafka-connect/values-dev.yaml \
  --namespace kafka-connect-dev
```

### Test
```bash
helm install kafka-connect helm/kafka-connect \
  --values helm/kafka-connect/values-test.yaml \
  --namespace kafka-connect-test
```

### Production
```bash
helm install kafka-connect helm/kafka-connect \
  --values helm/kafka-connect/values-prod.yaml \
  --namespace kafka-connect-prod
```

### Connectors Only (External Connect Cluster)
```bash
helm install connectors helm/kafka-connect \
  --values helm/kafka-connect/values-connectors-only.yaml \
  --namespace kafka-connect
```

## Connector Configuration

### File-based Configuration
Place connector configurations in `environments/{env}/connectors.yaml`:

```yaml
connectors:
  - name: my-connector
    config:
      connector.class: io.confluent.connect.s3.S3SinkConnector
      tasks.max: 3
      topics: my-topic
      # ... additional config
```

### Inline Configuration
```yaml
connectors:
  connectors:
    mainConfig: |
      connectors:
        - name: inline-connector
          config:
            connector.class: org.apache.kafka.connect.tools.MockSourceConnector
            tasks.max: 1
            topic: test-topic
```

## Helm Hook Lifecycle

The reconcile job runs as a Helm hook with these annotations:
- `helm.sh/hook: post-install,post-upgrade`
- `helm.sh/hook-weight: "1"`
- `helm.sh/hook-delete-policy: before-hook-creation,hook-succeeded`

This ensures:
1. Connectors are applied after the Connect cluster is ready
2. Old reconcile jobs are cleaned up
3. Successful jobs are removed to avoid clutter

## Independent Subchart Management

The connectors subchart can be managed independently:

```bash
# Update only connectors
helm upgrade kafka-connect helm/kafka-connect \
  --reuse-values \
  --set connectors.connectors.mainConfigFile=environments/prod/connectors-v2.yaml

# Disable connectors temporarily
helm upgrade kafka-connect helm/kafka-connect \
  --reuse-values \
  --set connectors.enabled=false
```

## Naming Consistency

Resources use consistent naming patterns:
- Main chart: `{release-name}-kafka-connect`
- Connectors: `{release-name}-connectors`
- ConfigMaps: `{release-name}-connectors`
- Jobs: `{release-name}-connectors-reconcile`

## Migration from Old Structure

The old flat chart structure has been reorganized into this modular design. Key changes:
1. Templates moved to appropriate chart locations
2. Values structure updated with global values and subchart configuration
3. Helm hooks added for proper lifecycle management
4. Environment-specific configurations separated
5. Enhanced reconcile job with pruning and better error handling