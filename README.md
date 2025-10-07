# Kafka Connect Platform Overview

This repository packages a Kafka Connect deployment that can be built, containerized, and installed into a Kubernetes cluster with Helm. The sections below describe the full lifecycle of the platform, runtime behavior, and the key configuration touchpoints that operators can adjust.

## End-to-End Workflow

### 1. Gradle Build

The Gradle project is responsible for producing the runtime artifacts (connectors, SMTs, and other plugins) that are bundled into the final Docker image. Running `./gradlew clean build` generates the plugin JARs under `build/libs/` and prepares any supporting resources required by the image. Customize dependencies and plugin versions in the Gradle build files when new connectors are added.

### 2. Docker Image Assembly

The Dockerfile consumes the Gradle output and produces a Kafka Connect runtime image. The build process typically copies the plugin artifacts into `/opt/kafka/plugins/`, layers health probe scripts, and configures startup scripts. When extending the image, keep the base Java version aligned with the target Kafka Connect release and use multi-stage builds to keep the runtime layer small.

### 3. Helm Chart Deployment

The Helm chart in `helm/` deploys the Kafka Connect cluster and orchestrates supporting Kubernetes objects (Deployments, ConfigMaps, Secrets, ServiceAccounts, and Jobs). To install or upgrade the release:

```bash
helm upgrade --install kafka-connect helm/ \
  -f helm/values-dev.yaml # or values-test.yaml / values-prod.yaml
```

The chart templates the StatefulSet/Deployment (depending on configuration), configures probe scripts, wires secret references, and creates a Job that reconciles connector definitions at startup. Helm values determine runtime configuration such as replica counts, resource requests, JVM settings, and connector bundles.

### 4. Runtime Behavior

At runtime, Kafka Connect nodes mount the packaged plugins and load configuration supplied through environment variables and files. The startup scripts set JVM flags, expose metrics, and register readiness/liveness probes. The reconciliation Job (or alternative controller) synchronizes desired connectors from `connectors/` with the Connect REST API so that deployed resources match the declarative definitions.

## JVM and Heap Sizing Guidance

Kafka Connect runs on the JVM, and heap sizing has a large impact on stability. The deployment exposes two primary environment variables for tuning:

- `KAFKA_HEAP_OPTS`: Sets `-Xms` and `-Xmx` to control the JVM heap size.
- `JAVA_OPTS_APPEND`: Appends additional JVM flags (e.g., GC tuning, diagnostics, or Off-Heap sizing hints).

Recommended baselines:

| Environment | Suggested Heap (`KAFKA_HEAP_OPTS`) | Additional Options (`JAVA_OPTS_APPEND`) |
|-------------|------------------------------------|-----------------------------------------|
| Development | `-Xms512m -Xmx512m`                | `-XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| Test        | `-Xms1g -Xmx1g`                    | `-XX:+UseG1GC -XX:MaxGCPauseMillis=200` |
| Production  | `-Xms4g -Xmx4g` (scale per load)   | `-XX:+UseG1GC -XX:MaxGCPauseMillis=100 -XX:+HeapDumpOnOutOfMemoryError` |

Update the corresponding Helm values (e.g., `helm/values-*.yaml`) under `env:` or `jvm:` sections to override defaults per environment. For production, monitor heap usage and adjust upward as connector volume grows.

## Connector Reconciliation

Connector definitions live in the `connectors/` directory. Each file represents a declarative Kafka Connect configuration in JSON or properties format. During deployment:

1. Helm renders a Kubernetes Job (e.g., `connect-reconciler`) that mounts the `connectors/` ConfigMap.
2. The Job runs a script or lightweight controller that iterates through the definitions and calls the Kafka Connect REST API (`/connectors`) to create, update, or delete connectors so the live cluster matches the desired state.
3. Alternative mechanisms (such as ArgoCD hooks or an external GitOps controller) can be configured by swapping out the Job command while still consuming the same ConfigMap.

Adjust the Job image, command, or scheduling by editing the Helm templates under `helm/templates/connector-reconciler-job.yaml` (or similar) and the supporting scripts described below.

## Scripts, Probes, and Supporting Assets

- `scripts/`: Contains helper utilities used during image build and runtime. Examples include:
  - `scripts/apply-connectors.sh`: Called by the reconciliation Job to apply connector definitions.
  - `scripts/wait-for-connect.sh`: Blocks until the Kafka Connect REST endpoint is responsive.
  - `scripts/configure-plugins.sh`: Prepares plugin directories before Kafka Connect starts.
- `probes/`: Houses readiness and liveness probe scripts invoked by Kubernetes. Customize thresholds or endpoints here if service behavior changes.
- `helm/values-*.yaml`: Environment-specific overrides for development, testing, and production. These files set replica counts, resource requests/limits, JVM options, probe timings, and connector reconciliation toggles.

When adjusting configuration for a specific environment, start by editing the appropriate `values-*.yaml` file, then override with `--set` flags only for ad-hoc changes. Scripts can be extended to cover additional operational requirements such as metrics exports or configuration validation.

## Getting Started

1. Build the project: `./gradlew clean build`
2. Build and push the Docker image: `docker build -t <registry>/kafka-connect:<tag> .`
3. Deploy to Kubernetes: `helm upgrade --install kafka-connect helm/ -f helm/values-dev.yaml`
4. Monitor logs and the Kafka Connect REST API to verify connectors are running.

For detailed configuration options, inspect the Helm chart values and templates, then adjust scripts or Docker build steps as necessary to meet your organization's operational standards.
