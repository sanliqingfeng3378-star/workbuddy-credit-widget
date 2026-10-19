#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache
swiftc -module-cache-path build/ModuleCache Shared/CreditModels.swift App/CreditBridge.swift Tests/main.swift -o build/credit-tests
build/credit-tests
swiftc -parse-as-library -module-cache-path build/ModuleCache Shared/CreditModels.swift App/CreditBridge.swift Tests/BridgeServer.swift -o build/bridge-test-server
python3 Tests/bridge_integration.py
