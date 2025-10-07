# Quick Start Guide - See Kafka Connect Running

## Option 1: Docker Compose (Simplest)

1. **Start Docker Desktop**
2. **Run the stack:**
   ```bash
   docker-compose up -d
   ```

3. **Watch logs in real-time:**
   ```bash
   # All services
   docker-compose logs -f
   
   # Just Kafka Connect
   docker-compose logs -f kafka-connect
   
   # Just the reconciliation container
   docker-compose logs -f connector-reconcile
   ```

4. **Check Kafka Connect Web UI:**
   - Open: http://localhost:8083
   - API: http://localhost:8083/connectors

5. **Test connector creation:**
   ```bash
   # Create a test connector
   curl -X POST http://localhost:8083/connectors \
     -H "Content-Type: application/json" \
     -d '{
       "name": "test-source",
       "config": {
         "connector.class": "org.apache.kafka.connect.tools.MockSourceConnector",
         "tasks.max": "1",
         "topic": "test-topic"
       }
     }'
   
   # List connectors
   curl http://localhost:8083/connectors
   
   # Get connector status
   curl http://localhost:8083/connectors/test-source/status
   ```

## Option 2: Kubernetes with Kind

1. **Start Docker Desktop**
2. **Create cluster:**
   ```bash
   kind create cluster --name kafka-connect-demo
   ```

3. **Load your image:**
   ```bash
   kind load docker-image kafka-connect:local --name kafka-connect-demo
   ```

4. **Install with Helm:**
   ```bash
   helm install demo helm --values helm/values-helm-test.yaml
   ```

5. **Watch deployment:**
   ```bash
   # Watch pods start
   kubectl get pods -w
   
   # Check job logs
   kubectl logs job/demo-kafka-connect-reconcile -f
   
   # Port-forward to access
   kubectl port-forward svc/demo-kafka-connect 8083:8083
   ```

## Option 3: Local Development Mode

Run just Kafka Connect locally for testing:

```bash
# Start Kafka and Zookeeper
docker run -d --name zookeeper -p 2181:2181 confluentinc/cp-zookeeper:7.5.0
docker run -d --name kafka -p 9092:9092 --link zookeeper confluentinc/cp-kafka:7.5.0

# Run your Kafka Connect image
docker run -d --name kafka-connect-local \
  -p 8083:8083 \
  --link kafka \
  -e CONNECT_BOOTSTRAP_SERVERS=kafka:29092 \
  -e CONNECT_REST_ADVERTISED_HOST_NAME=localhost \
  kafka-connect:local
```

## Monitoring Commands

Once running, use these to see activity:

```bash
# Connector status
curl http://localhost:8083/connectors | jq

# Connector details
curl http://localhost:8083/connectors/CONNECTOR_NAME/config | jq

# Task status
curl http://localhost:8083/connectors/CONNECTOR_NAME/tasks | jq

# Cluster info
curl http://localhost:8083/ | jq
```