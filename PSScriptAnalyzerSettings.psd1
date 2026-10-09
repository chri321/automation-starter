# PSScriptAnalyzer settings
#
# Adapted from snowdreamtech/template (PSScriptAnalyzerSettings.psd1).
# Reference: https://github.com/PowerShell/PSScriptAnalyzer

@{
    # Include every default rule, then carve out the documented exceptions.
    IncludeDefaultRules = $true

    ExcludeRules = @(
        # Conflicts with .editorconfig, which mandates UTF-8 WITHOUT a BOM.
        # Mixing BOM and non-BOM files across a repo causes spurious diffs.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
