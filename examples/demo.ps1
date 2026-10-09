<#
    demo.ps1 - thin PowerShell wrapper around demo.sh.

    This file MUST stay logic-free. All behaviour lives in demo.sh, which is
    the single source of truth. See .agent/rules/shell.md section 6.
#>

. "$PSScriptRoot/../lib/common.ps1"

Invoke-ShellDelegation (Join-Path $PSScriptRoot 'demo.sh') $args
