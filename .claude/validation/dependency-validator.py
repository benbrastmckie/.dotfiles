#!/usr/bin/env python3
"""
Dependency Validation Script for Claude Commands
Validates the 4-layer dependency architecture to prevent circular dependencies
"""

import os
import re
import json
import sys
from pathlib import Path
from typing import Dict, List, Set, Optional

# Define the 4-layer architecture
LAYER_DEFINITIONS = {
    1: {
        "name": "Core Foundation Services",
        "commands": ["coordination-hub", "resource-manager"],
        "allowed_dependencies": []
    },
    2: {
        "name": "Monitoring and Status Services",
        "commands": ["workflow-status", "performance-monitor"],
        "allowed_dependencies": ["coordination-hub", "resource-manager"]
    },
    3: {
        "name": "Advanced Workflow Services",
        "commands": ["workflow-recovery", "progress-aggregator", "dependency-resolver"],
        "allowed_dependencies": ["coordination-hub", "resource-manager", "workflow-status", "performance-monitor"]
    },
    4: {
        "name": "Complete Workflow Orchestration",
        "commands": ["orchestrate"],
        "allowed_dependencies": ["coordination-hub", "resource-manager", "workflow-status", "performance-monitor",
                               "workflow-recovery", "progress-aggregator", "dependency-resolver"]
    }
}

class DependencyValidator:
    def __init__(self, commands_dir: str = "/home/benjamin/.dotfiles/.claude/commands"):
        self.commands_dir = Path(commands_dir)
        self.command_dependencies = {}
        self.command_to_layer = {}
        self.violations = []

        # Build reverse mapping
        for layer, config in LAYER_DEFINITIONS.items():
            for command in config["commands"]:
                self.command_to_layer[command] = layer

    def parse_command_file(self, file_path: Path) -> Dict:
        """Parse a command file to extract dependencies from YAML frontmatter"""
        try:
            with open(file_path, 'r') as f:
                content = f.read()

            # Extract YAML frontmatter
            yaml_match = re.match(r'^---\s*\n(.*?)\n---', content, re.DOTALL)
            if not yaml_match:
                return {}

            yaml_content = yaml_match.group(1)

            # Parse dependent-commands field
            deps_match = re.search(r'^dependent-commands:\s*(.*)$', yaml_content, re.MULTILINE)
            if not deps_match:
                return {"dependencies": []}

            deps_line = deps_match.group(1).strip()
            if not deps_line or deps_line == "":
                return {"dependencies": []}

            # Parse comma-separated dependencies
            dependencies = [dep.strip() for dep in deps_line.split(',') if dep.strip()]

            return {"dependencies": dependencies}

        except Exception as e:
            print(f"Error parsing {file_path}: {e}")
            return {}

    def load_all_dependencies(self):
        """Load dependencies from all command files"""
        for file_path in self.commands_dir.glob("*.md"):
            command_name = file_path.stem
            parsed = self.parse_command_file(file_path)
            self.command_dependencies[command_name] = parsed.get("dependencies", [])

    def validate_layer_compliance(self) -> List[str]:
        """Validate that commands only depend on lower layers"""
        violations = []

        for command, dependencies in self.command_dependencies.items():
            if command not in self.command_to_layer:
                continue  # Skip non-orchestration commands

            command_layer = self.command_to_layer[command]
            allowed_deps = LAYER_DEFINITIONS[command_layer]["allowed_dependencies"]

            for dep in dependencies:
                if dep in self.command_to_layer:
                    dep_layer = self.command_to_layer[dep]

                    # Check if dependency is from higher or same layer
                    if dep_layer >= command_layer:
                        violations.append(
                            f"LAYER VIOLATION: {command} (Layer {command_layer}) depends on "
                            f"{dep} (Layer {dep_layer}). Commands can only depend on lower layers."
                        )

                    # Check if dependency is allowed for this layer
                    if dep not in allowed_deps:
                        violations.append(
                            f"FORBIDDEN DEPENDENCY: {command} (Layer {command_layer}) depends on "
                            f"{dep} which is not in allowed dependencies: {allowed_deps}"
                        )

        return violations

    def detect_circular_dependencies(self) -> List[str]:
        """Detect circular dependencies using DFS"""
        violations = []
        visited = set()
        rec_stack = set()

        def dfs(command, path):
            if command in rec_stack:
                cycle_start = path.index(command)
                cycle = path[cycle_start:] + [command]
                violations.append(f"CIRCULAR DEPENDENCY: {' → '.join(cycle)}")
                return

            if command in visited:
                return

            visited.add(command)
            rec_stack.add(command)

            for dep in self.command_dependencies.get(command, []):
                if dep in self.command_dependencies:
                    dfs(dep, path + [command])

            rec_stack.remove(command)

        for command in self.command_dependencies:
            if command not in visited:
                dfs(command, [])

        return violations

    def validate_orchestration_commands(self) -> List[str]:
        """Validate that only orchestration commands are in the layer definitions"""
        violations = []

        for command in self.command_dependencies:
            if command in self.command_to_layer:
                # This is an orchestration command, it should follow layer rules
                continue
            else:
                # Check if it has dependencies on orchestration commands
                orchestration_deps = [dep for dep in self.command_dependencies[command]
                                    if dep in self.command_to_layer]
                if orchestration_deps:
                    violations.append(
                        f"NON-ORCHESTRATION DEPENDENCY: {command} (non-orchestration) depends on "
                        f"orchestration commands: {orchestration_deps}"
                    )

        return violations

    def generate_report(self) -> str:
        """Generate a comprehensive validation report"""
        report = []
        report.append("=" * 80)
        report.append("CLAUDE COMMANDS DEPENDENCY VALIDATION REPORT")
        report.append("=" * 80)
        report.append("")

        # Architecture summary
        report.append("LAYER ARCHITECTURE:")
        for layer, config in LAYER_DEFINITIONS.items():
            report.append(f"  Layer {layer}: {config['name']}")
            report.append(f"    Commands: {', '.join(config['commands'])}")
            if config['allowed_dependencies']:
                report.append(f"    Dependencies: {', '.join(config['allowed_dependencies'])}")
            else:
                report.append(f"    Dependencies: None (foundation layer)")
            report.append("")

        # Load and validate
        self.load_all_dependencies()

        layer_violations = self.validate_layer_compliance()
        circular_violations = self.detect_circular_dependencies()
        orchestration_violations = self.validate_orchestration_commands()

        all_violations = layer_violations + circular_violations + orchestration_violations

        if not all_violations:
            report.append("✅ VALIDATION PASSED")
            report.append("All dependencies comply with the 4-layer architecture.")
            report.append("No circular dependencies detected.")
        else:
            report.append("❌ VALIDATION FAILED")
            report.append(f"Found {len(all_violations)} violations:")
            report.append("")

            if layer_violations:
                report.append("LAYER COMPLIANCE VIOLATIONS:")
                for violation in layer_violations:
                    report.append(f"  • {violation}")
                report.append("")

            if circular_violations:
                report.append("CIRCULAR DEPENDENCY VIOLATIONS:")
                for violation in circular_violations:
                    report.append(f"  • {violation}")
                report.append("")

            if orchestration_violations:
                report.append("ORCHESTRATION BOUNDARY VIOLATIONS:")
                for violation in orchestration_violations:
                    report.append(f"  • {violation}")
                report.append("")

        # Current dependency mapping
        report.append("CURRENT DEPENDENCY MAPPING:")
        for command in sorted(self.command_dependencies.keys()):
            layer = self.command_to_layer.get(command, "non-orchestration")
            deps = self.command_dependencies[command]
            if deps:
                report.append(f"  {command} (Layer {layer}): {', '.join(deps)}")
            else:
                report.append(f"  {command} (Layer {layer}): no dependencies")

        report.append("")
        report.append("=" * 80)

        return "\n".join(report)

    def validate(self) -> bool:
        """Main validation function. Returns True if all validations pass."""
        self.load_all_dependencies()

        layer_violations = self.validate_layer_compliance()
        circular_violations = self.detect_circular_dependencies()
        orchestration_violations = self.validate_orchestration_commands()

        return len(layer_violations + circular_violations + orchestration_violations) == 0

def main():
    """Main function for command line usage"""
    import argparse

    parser = argparse.ArgumentParser(description="Validate Claude command dependencies")
    parser.add_argument("--commands-dir", default="/home/benjamin/.dotfiles/.claude/commands",
                       help="Directory containing command files")
    parser.add_argument("--report", action="store_true",
                       help="Generate detailed report")
    parser.add_argument("--quiet", action="store_true",
                       help="Only output errors")

    args = parser.parse_args()

    validator = DependencyValidator(args.commands_dir)

    if args.report:
        print(validator.generate_report())
        return

    is_valid = validator.validate()

    if is_valid:
        if not args.quiet:
            print("✅ All dependency validations passed!")
        sys.exit(0)
    else:
        print("❌ Dependency validation failed!")
        if not args.quiet:
            print("\nRun with --report for detailed information.")
        sys.exit(1)

if __name__ == "__main__":
    main()