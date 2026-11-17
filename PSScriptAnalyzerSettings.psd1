# PSScriptAnalyzer settings (used locally and in CI)
@{
    Severity     = @('Error', 'Warning')
    # setup.ps1 is an interactive installer: coloured Write-Host output IS its user interface.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
