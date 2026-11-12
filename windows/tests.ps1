# Run in an isolated process: pwsh -NoLogo -NoProfile -File windows\tests.ps1
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'profile.ps1')
. (Join-Path $PSScriptRoot 'keybindings.ps1')

# Prediction requires a real terminal; exercise the remaining setup when redirected.
function Set-PSReadLineOption {
    $options = @{}
    for ($i = 0; $i -lt $args.Count; $i += 2) {
        $options[$args[$i].TrimStart('-').TrimEnd(':')] = $args[$i + 1]
    }
    $options.Remove('PredictionSource')
    PSReadLine\Set-PSReadLineOption @options
}
try {
    Set-ShellKeyBindings
    Set-ShellKeyBindings
    $bindings = @{
        Spacebar = 'SelfInsert'
        'Ctrl+Spacebar' = 'AcceptSuggestion'
        'Alt+Spacebar' = 'AcceptNextSuggestionWord'
        'Ctrl+Alt+RightArrow' = 'AcceptNextSuggestionWord'
    }
    foreach ($chord in $bindings.Keys) {
        $handler = Get-PSReadLineKeyHandler -Chord $chord
        if ($handler.Function -ne $bindings[$chord]) { throw "Incorrect binding for $chord." }
    }
    Write-Output 'PASS: plain Space inserts text; suggestion shortcuts remain separate after reload.'
}
finally { Remove-Item Function:\Set-PSReadLineOption }

$temp = Join-Path ([IO.Path]::GetTempPath()) ("shell-parity-" + [guid]::NewGuid())
$oldDatabase = $env:ZOXIDE_DB_DIR
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $directory = Join-Path $temp "parity's folder"
    New-Item -ItemType Directory -Path $directory | Out-Null
    New-Item -ItemType File -Path (Join-Path $directory 'preview-child.txt') | Out-Null
    $quoted = "'" + $directory.Replace("'", "''") + "'"
    $data = Join-Path $temp 'completions.json'
    @(
        @{ CompletionText = $quoted; ToolTip = 'directory'; ResultType = [System.Management.Automation.CompletionResultType]::ProviderContainer }
        @{ CompletionText = '-Path'; ToolTip = 'parameter-help-sentinel'; ResultType = [System.Management.Automation.CompletionResultType]::ParameterName }
        @{ CompletionText = $quoted; ToolTip = 'command-help-sentinel'; ResultType = [System.Management.Automation.CompletionResultType]::Text }
    ) | ConvertTo-Json | Set-Content -LiteralPath $data -Encoding utf8

    $preview = & (Join-Path $PSScriptRoot 'completion-preview.ps1') -DataPath $data -Index 0 | Out-String
    if ($preview -notmatch 'preview-child.txt') { throw 'Directory preview failed for a path containing a space and apostrophe.' }
    $help = & (Join-Path $PSScriptRoot 'completion-preview.ps1') -DataPath $data -Index 1
    if ($help -ne 'parameter-help-sentinel') { throw 'Non-path completion tooltip was lost.' }
    $help = & (Join-Path $PSScriptRoot 'completion-preview.ps1') -DataPath $data -Index 2
    if ($help -ne 'command-help-sentinel') { throw 'Command help was replaced by a coincidentally matching directory.' }

    $env:ZOXIDE_DB_DIR = Join-Path $temp 'zoxide'
    zoxide add -- $directory
    if ($LASTEXITCODE) { throw 'Could not seed isolated zoxide database.' }
    Invoke-Expression (zoxide init powershell | Out-String)
    $originalPrompt = $function:prompt
    Initialize-Completions
    if ($function:prompt.ToString() -ne $originalPrompt.ToString()) { throw 'Git completion setup changed the prompt.' }
    Push-Location (Split-Path $PSScriptRoot -Parent)
    try {
        $line = 'git '
        $matches = (Get-ShellCompletion $line $line.Length).CompletionMatches
        foreach ($command in 'checkout', 'status', 'commit') {
            $match = $matches | Where-Object CompletionText -eq $command
            if (-not $match -or $match.ToolTip -eq $command) { throw "Git subcommand/help completion missing: $command" }
        }
        if ($matches.ResultType -contains 'ProviderContainer') { throw 'git<Tab> returned directories instead of subcommands.' }
        $line = 'git checkout '
        $matches = (Get-ShellCompletion $line $line.Length).CompletionMatches
        $branch = git branch --show-current
        if ($branch -notin $matches.CompletionText) { throw 'Git checkout did not complete local branches.' }
        $line = 'gc '
        $matches = (Get-ShellCompletion $line $line.Length).CompletionMatches
        if ($branch -notin $matches.CompletionText) { throw 'The gc shortcut did not inherit checkout completion.' }
        $line = 'git status --'
        $matches = (Get-ShellCompletion $line $line.Length).CompletionMatches
        if ('--short' -notin $matches.CompletionText) { throw 'Git option completion was lost.' }
    }
    finally { Pop-Location }
    function Test-ShellCompletion { param([string]$Mode) }
    Register-ArgumentCompleter -CommandName Test-ShellCompletion -ParameterName Mode -ScriptBlock {
        [System.Management.Automation.CompletionResult]::new('specific-value', 'specific-value', 'ParameterValue', 'specific-help')
    }
    $line = 'Test-ShellCompletion -Mode '
    $matches = (Get-ShellCompletion $line $line.Length).CompletionMatches
    if ($matches.CompletionText -ne 'specific-value' -or $matches.ToolTip -ne 'specific-help') {
        throw 'A registered function completer was replaced with path completion.'
    }
    Write-Output 'PASS: Git subcommands/descriptions, branch/option context, custom function completions and prompt preservation.'
    $line = 'z parity'
    $matches = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null).CompletionMatches
    if ($quoted -notin $matches.CompletionText) { throw 'z<Tab> did not return the quoted zoxide-ranked directory.' }
    $line = "cd '$temp\par"
    $matches = [System.Management.Automation.CommandCompletion]::CompleteInput($line, $line.Length, $null).CompletionMatches
    if (-not $matches.Count) { throw 'cd path completion returned no candidates.' }
    $matches | Select-Object CompletionText, ToolTip, ResultType | ConvertTo-Json |
        Set-Content -LiteralPath $data -Encoding utf8
    $preview = & (Join-Path $PSScriptRoot 'completion-preview.ps1') -DataPath $data -Index 0 | Out-String
    if ($preview -notmatch 'preview-child.txt') { throw 'cd completion lost its directory preview.' }

    $handler = Get-PSReadLineKeyHandler -Chord Tab
    if ($handler.Function -ne 'FzfCompletion') { throw 'Tab was not bound to the tooltip-aware fzf picker.' }
    ls $PSScriptRoot | Out-Null
    if ($LASTEXITCODE) { throw 'The Windows eza listing options are not supported.' }
    Write-Output 'PASS: quoted directory previews, tooltip fallback, zoxide completions, cd previews and Tab binding.'
}
finally {
    $env:ZOXIDE_DB_DIR = $oldDatabase
    Remove-Item -LiteralPath $temp -Recurse -Force
}
