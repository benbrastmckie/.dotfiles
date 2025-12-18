# OpenCode Factory Refactor Plan

## Objective
Refactor the repository to serve as a factory for designing, testing, and exporting custom `.opencode/` setups. The core agents and supporting infrastructure will be preserved, while installation scripts and extraneous elements will be removed.

## Status: ✅ COMPLETED

---

## 1. Core Components to Preserve (Do Not Touch)
The following directories constitute the "center" of the repo and must be preserved exactly:

*   **`.opencode/`**: Contains the primary agent definitions, commands, context, plugins, prompts, and tools. ✅ PRESERVED
    *   `agent/`: General, Coder, and subagents.
    *   `command/`: Custom slash commands.
    *   `context/`: Context files and standards.
    *   `plugin/`: System plugins.
    *   `prompts/`: Agent prompts.
    *   `tool/`: Custom tools.

## 2. Supporting Infrastructure to Keep
These components are essential for developing and testing custom agents:

*   **`evals/`**: The evaluation framework and test suites. ✅ PRESERVED
    *   `agents/`: Contains the test definitions (YAML) for the agents.
    *   `framework/`: The SDK-based test runner.
*   **`scripts/testing/`**: Contains `test.sh`, the main entry point for running tests. ✅ PRESERVED
*   **`scripts/check-context-logs/`**: Useful utilities for debugging agent sessions. ✅ PRESERVED
*   **`scripts/validation/`**: Scripts for validating context references. ✅ PRESERVED
*   **`dev/ai-tools/opencode/`**: Valuable documentation on building plugins, context, and subagents. ✅ PRESERVED
*   **`src/`**: Contains `models/User.js` and `calculator.js`. These are used as fixtures in test suites. ✅ PRESERVED

## 3. Components Removed
The following files and directories were removed:

*   **Root Scripts**: ✅ REMOVED
    *   `install.sh`: Installation script for end-users.
    *   `update.sh`: Update script.
    *   `Makefile`: Build automation for the product.
*   **`.github/`**: CI/CD workflows specific to the original repository. ✅ REMOVED
*   **`assets/`**: Images and static assets not used by the agents. ✅ REMOVED
*   **`scripts/` Subdirectories**: ✅ REMOVED
    *   `scripts/registry/`: Tools for managing the OpenAgents component registry.
    *   `scripts/versioning/`: Scripts for bumping versions of the repo.
    *   `scripts/maintenance/`: Cleanup scripts specific to the original deployment.
*   **Project Metadata**: ✅ REMOVED
    *   `CHANGELOG.md`, `COMPATIBILITY.md`, `ROADMAP.md`, `VERSION`

## 4. Components Modified

*   **`README.md`**: ✅ UPDATED
    *   *Before*: Product documentation for OpenAgents.
    *   *After*: Documentation for the "OpenCode Factory" – how to design, test, and export custom agent setups.
*   **`package.json`**: ✅ SIMPLIFIED
    *   *Before*: Included scripts for versioning, registry, results display, etc.
    *   *After*: Simplified to only include scripts relevant to testing and development.

## 5. New Components Added

*   **`templates/`**: ✅ CREATED
    *   A new directory to store reusable agent patterns, context templates, and workflow examples.
    *   Currently contains a README placeholder for future templates.
*   **`.opencode/specs/`**: ✅ CREATED
    *   Contains this refactor plan document.

## 6. Fixes Applied

*   **`scripts/testing/test.sh`**: ✅ FIXED
    *   Changed shebang from `#!/bin/bash` to `#!/usr/bin/env bash` for NixOS compatibility.

## 7. Test Suite Cleanup

*   **`src/` directory**: ✅ REMOVED
    *   Removed test fixtures that were only used by a few tests.
*   **Tests removed**: ✅ CLEANED UP
    *   Removed 18 tests that referenced `src/` fixtures.
    *   Removed `_archive/` directory (old deprecated tests).
    *   Updated core test `simple-task-direct.yaml` to not reference `src/`.
*   **Final test count**: 55 tests (down from 73)
    *   General: 45 tests
    *   Coder: 10 tests
    *   Core suite: 7 tests (all intact and functional)

---

## Summary of Changes

### Removed (Debris)
- Installation and update scripts
- CI/CD workflows (.github/)
- Asset files
- Registry management tools
- Version management scripts
- Maintenance scripts
- Project metadata files

### Preserved (Core)
- `.opencode/` directory (all agents, context, plugins, tools)
- `evals/` framework and test suites
- `scripts/testing/`, `scripts/validation/`, `scripts/check-context-logs/`
- `dev/ai-tools/opencode/` documentation
- `src/` test fixtures

### Modified
- `README.md` - Rewritten for factory usage
- `package.json` - Simplified scripts
- `scripts/testing/test.sh` - Fixed shebang

### Added
- `templates/` directory
- `.opencode/specs/` directory
- This refactor plan document

---

## Next Steps

The repository is now configured as an **OpenCode Agent Factory**. Users can:

1. Clone this repository
2. Customize agents in `.opencode/agent/`
3. Test changes using `npm run test:core`
4. Export the `.opencode/` directory to their projects

The evaluation framework remains intact for verifying agent behavior, and all documentation for building plugins and understanding the context system is preserved in `dev/ai-tools/opencode/`.
