#!/bin/bash

# Tool Allocation Validation Script
echo "=== Tool Allocation Validation Report ==="
echo "Date: $(date)"
echo

# Define standard patterns
ORCHESTRATION_TOOLS="SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob"
PRIMARY_TOOLS="SlashCommand, TodoWrite, Read, Write, Bash, Grep, Glob, Task"
UTILITY_TOOLS="SlashCommand, TodoWrite, Read, Write, Bash"
DEPENDENT_TOOLS="SlashCommand, Read, Write, TodoWrite"

echo "Standard Tool Patterns:"
echo "- Orchestration: [$ORCHESTRATION_TOOLS]"
echo "- Primary: [$PRIMARY_TOOLS]"
echo "- Utility: [$UTILITY_TOOLS]"
echo "- Dependent: [$DEPENDENT_TOOLS]"
echo

total_files=0
compliant_files=0
issues_found=0

cd /home/benjamin/.dotfiles/.claude/commands

for file in *.md; do
    if [[ -f "$file" ]]; then
        total_files=$((total_files + 1))
        echo "=== $file ==="

        # Extract metadata
        allowed_tools=$(grep "^allowed-tools:" "$file" | sed 's/allowed-tools: *//')
        command_type=$(grep "^command-type:" "$file" | sed 's/command-type: *//')

        echo "  Type: $command_type"
        echo "  Tools: $allowed_tools"

        # Validate based on type
        case "$command_type" in
            "orchestration")
                expected="$ORCHESTRATION_TOOLS"
                ;;
            "primary")
                expected="$PRIMARY_TOOLS"
                ;;
            "utility")
                expected="$UTILITY_TOOLS"
                ;;
            "dependent")
                expected="$DEPENDENT_TOOLS"
                ;;
            *)
                echo "  Status: ❌ UNKNOWN TYPE"
                issues_found=$((issues_found + 1))
                continue
                ;;
        esac

        # Normalize for comparison (sort and remove spaces)
        normalized_actual=$(echo "$allowed_tools" | tr ', ' '\n' | sort | tr '\n' ',' | sed 's/,$//')
        normalized_expected=$(echo "$expected" | tr ', ' '\n' | sort | tr '\n' ',' | sed 's/,$//')

        if [[ "$normalized_actual" == "$normalized_expected" ]]; then
            echo "  Status: ✅ COMPLIANT"
            compliant_files=$((compliant_files + 1))
        else
            echo "  Status: ❌ NON-COMPLIANT"
            echo "  Expected: $expected"
            issues_found=$((issues_found + 1))
        fi
        echo
    fi
done

echo "=== SUMMARY ==="
echo "Total files checked: $total_files"
echo "Compliant files: $compliant_files"
echo "Non-compliant files: $((total_files - compliant_files))"
echo "Issues found: $issues_found"
echo "Compliance rate: $(( (compliant_files * 100) / total_files ))%"

if [[ $issues_found -eq 0 ]]; then
    echo "🎉 All tool allocations are compliant!"
    exit 0
else
    echo "⚠️  Found $issues_found tool allocation issues"
    exit 1
fi