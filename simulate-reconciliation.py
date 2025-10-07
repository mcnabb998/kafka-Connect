#!/usr/bin/env python3
"""
Simulate the Kafka Connect reconciliation process locally
This shows you exactly what your Helm Job would do when deployed
"""

import json
import yaml
from pathlib import Path

def load_connector_documents(base_path: Path):
    """Load connector definitions from files"""
    connectors = []
    
    for file_path in sorted(base_path.iterdir()):
        if not file_path.is_file():
            continue
            
        print(f"📁 Processing file: {file_path}")
        
        text = file_path.read_text(encoding='utf-8')
        if not text.strip():
            continue
            
        try:
            # Try YAML first, then JSON
            try:
                data = yaml.safe_load(text)
            except yaml.YAMLError:
                data = json.loads(text)
                
            print(f"✅ Loaded data: {type(data).__name__}")
            
        except (json.JSONDecodeError, yaml.YAMLError) as exc:
            print(f"❌ Skipping {file_path}: Invalid format - {exc}")
            continue
            
        # Handle different file formats
        if isinstance(data, dict) and "connectors" in data:
            # Multi-connector file
            for connector in data.get("connectors", []):
                connectors.append(connector)
                print(f"  📎 Found connector: {connector.get('name', 'unnamed')}")
        elif isinstance(data, dict) and "name" in data:
            # Single connector file
            connectors.append(data)
            print(f"  📎 Found connector: {data.get('name', 'unnamed')}")
        else:
            print(f"  ⚠️  Unknown format in {file_path}")
    
    return connectors

def simulate_upsert_connector(connector: dict):
    """Simulate creating/updating a connector"""
    name = connector.get("name")
    if not name:
        print("❌ Connector missing 'name' field")
        return False
        
    config = connector.get("config", {})
    connector_class = config.get("connector.class", "Unknown")
    
    print(f"🔄 Would create/update connector:")
    print(f"   Name: {name}")
    print(f"   Class: {connector_class}")
    print(f"   Config keys: {list(config.keys())}")
    
    # Simulate REST API call
    payload = {"name": name, "config": config}
    print(f"   📡 Would POST to: /connectors")
    print(f"   📦 Payload size: {len(json.dumps(payload))} bytes")
    
    return True

def main():
    print("🚀 Kafka Connect Reconciliation Simulation")
    print("=" * 50)
    
    # Simulate mounted ConfigMap directory
    connectors_dir = Path("connectors")
    
    if not connectors_dir.exists():
        print(f"❌ Directory {connectors_dir} not found")
        return
        
    print(f"📂 Loading connectors from: {connectors_dir.absolute()}")
    print()
    
    # Load all connector definitions
    connectors = load_connector_documents(connectors_dir)
    
    print()
    print(f"📊 Summary: Found {len(connectors)} connectors")
    print("-" * 30)
    
    success_count = 0
    
    # Process each connector
    for i, connector in enumerate(connectors, 1):
        print(f"\n🔧 Processing connector {i}/{len(connectors)}:")
        if simulate_upsert_connector(connector):
            success_count += 1
        print()
    
    print("=" * 50)
    print(f"✅ Successfully processed: {success_count}/{len(connectors)} connectors")
    
    if success_count == len(connectors):
        print("🎉 All connectors would be created successfully!")
    else:
        print("⚠️  Some connectors had issues")

if __name__ == "__main__":
    main()