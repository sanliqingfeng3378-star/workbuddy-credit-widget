#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/ModuleCache
swiftc -module-cache-path build/ModuleCache Shared/CreditModels.swift App/CreditBridge.swift Tests/main.swift -o build/credit-tests
build/credit-tests
swiftc -parse-as-library -module-cache-path build/ModuleCache Shared/CreditModels.swift App/CreditBridge.swift Tests/BridgeServer.swift -o build/bridge-test-server
python3 Tests/bridge_integration.py
swiftc -parse-as-library -module-cache-path build/ModuleCache Shared/RefreshPolicy.swift App/AppPreferences.swift App/LoginItemManager.swift Tests/SettingsTests.swift -o build/settings-tests
build/settings-tests
swiftc -parse-as-library -module-cache-path build/ModuleCache App/WidgetRepair.swift Tests/WidgetRepairTests.swift -o build/widget-repair-tests
build/widget-repair-tests
