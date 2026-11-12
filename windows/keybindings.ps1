# keybindings.ps1 - PSReadLine / fzf / completion setup. Twin of the ZLE half of
# zsh/functions.zsh (setkeybindings, fzfinit) plus the autosuggest/highlight
# styling from home/.zshrc.
# Needs PowerShell 7 and PSReadLine 2.2+ for inline suggestions; install.ps1 sets that up.

$script:Esc = [char]27

function Get-CompletionPath {
    param([string]$Text)
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$tokens, [ref]$errors)
    $expression = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.StringConstantExpressionAst]
    }, $true)
    if (-not $errors -and $expression) { $expression.Value } else { $Text }
}

function Get-ShellCompletion {
    param([string]$Line, [int]$Cursor)
    $completion = [System.Management.Automation.CommandCompletion]::CompleteInput($Line, $Cursor, $null)
    if ($Line.Substring(0, $Cursor) -match '^\s*git(?:\.exe)?\s+([^\s]*)$') {
        $prefix = $Matches[1]
        if (-not $script:GitCommandDescriptions) {
            $descriptions = git --no-pager help -a --no-aliases --no-external-commands
            if ($LASTEXITCODE) { throw 'Could not load Git subcommand descriptions.' }
            $script:GitCommandDescriptions = @{}
            foreach ($description in $descriptions) {
                if ($description -match '^\s{3}(\S+)\s{2,}(.+)$') {
                    $script:GitCommandDescriptions[$Matches[1]] = $Matches[2]
                }
            }
        }
        for ($i = 0; $i -lt $completion.CompletionMatches.Count; $i++) {
            $match = $completion.CompletionMatches[$i]
            if ($script:GitCommandDescriptions.ContainsKey($match.CompletionText)) {
                $completion.CompletionMatches[$i] = [System.Management.Automation.CompletionResult]::new(
                    $match.CompletionText, $match.ListItemText, $match.ResultType,
                    $script:GitCommandDescriptions[$match.CompletionText]
                )
            }
        }
        foreach ($command in ($script:GitCommandDescriptions.Keys | Sort-Object)) {
            if ($command.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
                $command -notin $completion.CompletionMatches.CompletionText) {
                $completion.CompletionMatches.Add([System.Management.Automation.CompletionResult]::new(
                    $command, $command, 'ParameterValue', $script:GitCommandDescriptions[$command]
                ))
            }
        }
    }
    $completion
}

function Invoke-CompletionPrompt {
    $encoding = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)
        [Microsoft.PowerShell.PSConsoleReadLine]::InvokePrompt()
    }
    finally { [Console]::OutputEncoding = $encoding }
}

function Set-ShellKeyBindings {
    if (-not (Get-Module -ListAvailable PSReadLine)) { return }
    Import-Module PSReadLine

    # ~~~~~~~~~~~~~~~~~~ History / autosuggest (zsh-autosuggestions) ~~~~~~~~~~~~~~~~~~~
    $options = @{
        EditMode                      = 'Windows'
        BellStyle                     = 'None'
        MaximumHistoryCount           = 9999
        HistoryNoDuplicates           = $true
        HistorySearchCursorMovesToEnd = $true
        HistorySaveStyle              = 'SaveIncrementally'
        PredictionSource              = 'History'     # ZSH_AUTOSUGGEST_STRATEGY=(history ...)
        PredictionViewStyle           = 'InlineView'  # ghost text after the cursor
    }
    foreach ($o in $options.GetEnumerator()) {
        $setting = @{ $o.Key = $o.Value }
        Set-PSReadLineOption -ErrorAction Stop @setting
    }

    # ~~~~~~~~~~~~~~~~~~ Syntax highlighting (zsh-syntax-highlighting) ~~~~~~~~~~~~~~~~~~~
    # Same xterm-256 numbers as ZSH_HIGHLIGHT_STYLES / ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE.
    $fg = { param($n, $extra = '') '{0}[38;5;{1}{2}m' -f $script:Esc, $n, $extra }
    Set-PSReadLineOption -Colors @{
            Command          = & $fg 80
            Keyword          = & $fg 126 ';4'
            Parameter        = & $fg 81
            Operator         = & $fg 81
            Variable         = & $fg 79
            Member           = & $fg 67
            Type             = & $fg 67
            String           = & $fg 177
            Number           = & $fg 177
            Comment          = & $fg 244
            Default          = "$($script:Esc)[35m"
            Error            = & $fg 11
            InlinePrediction = & $fg 131 ';7'
    }

    # ~~~~~~~~~~~~~~~~~~ Key bindings ~~~~~~~~~~~~~~~~~~~
    # Up/Down browse history filtered by what's typed (zsh: ghost-text history).
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+Space accepts the whole suggestion, Alt+Space one word.
    try { Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function AcceptSuggestion } catch {}
    try { Set-PSReadLineKeyHandler -Chord 'Alt+Spacebar' -Function AcceptNextSuggestionWord } catch {}
    # Ctrl+Alt+Space can normalize to plain Space with Windows AltGr handling.
    Set-PSReadLineKeyHandler -Chord 'Ctrl+Alt+RightArrow' -Function AcceptNextSuggestionWord
    Set-PSReadLineKeyHandler -Chord 'Spacebar' -Function SelfInsert
    Set-PSReadLineKeyHandler -Chord 'Alt+LeftArrow' -Function ShellBackwardWord
    Set-PSReadLineKeyHandler -Chord 'Alt+RightArrow' -Function ShellForwardWord
    Set-PSReadLineKeyHandler -Chord 'Alt+Shift+LeftArrow' -Function SelectShellBackwardWord
    Set-PSReadLineKeyHandler -Chord 'Alt+Shift+RightArrow' -Function SelectShellForwardWord

    # Windows muscle memory: Ctrl+Z undoes, Ctrl+Shift+Z / Ctrl+Y / Alt+- redo.
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    foreach ($chord in 'Ctrl+Shift+z', 'Ctrl+y', 'Alt+-') {
        try { Set-PSReadLineKeyHandler -Chord $chord -Function Redo } catch {}
    }

    # No key may wipe text or the whole line by accident (home-row-mod misfires).
    # Ctrl+Backspace / Alt+Backspace stay as the one deliberate word-delete.
    foreach ($chord in 'Ctrl+d', 'Ctrl+Delete', 'Ctrl+Home', 'Ctrl+End', 'Ctrl+k', 'Ctrl+u',
                       'Ctrl+w', 'Alt+d', 'Escape') {
        try { Remove-PSReadLineKeyHandler -Chord $chord -ErrorAction Stop } catch {}
    }
    Set-PSReadLineKeyHandler -Chord 'Alt+Backspace' -Function BackwardKillWord

    # Alt+c: copy the selection, or from the cursor to the end of the line.
    # (PSReadLine doesn't expose the grey suggestion text, so it isn't included.)
    Set-PSReadLineKeyHandler -Chord 'Alt+c' -BriefDescription CopySelectionOrRest -ScriptBlock {
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $start = $null; $length = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetSelectionState([ref]$start, [ref]$length)
        $text = if ($start -ge 0 -and $length -gt 0) { $line.Substring($start, $length) } else { $line.Substring($cursor) }
        if ($text) { Set-Clipboard -Value $text }
    }

    # Ctrl+x: expand the alias/function-shortcut under the cursor in place.
    Set-PSReadLineKeyHandler -Chord 'Ctrl+x' -BriefDescription ExpandAlias -ScriptBlock {
        $ast = $null; $tokens = $null; $errors = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$ast, [ref]$tokens, [ref]$errors, [ref]$cursor)
        foreach ($t in $tokens) {
            if ($t.Extent.StartOffset -le $cursor -and $cursor -le $t.Extent.EndOffset -and $t.TokenFlags -band 'CommandName') {
                $cmd = Get-Command $t.Text -ErrorAction SilentlyContinue
                $body = if ($cmd.CommandType -eq 'Alias') { $cmd.Definition }
                        elseif ($cmd.CommandType -eq 'Function') { ($cmd.Definition.Trim() -replace '\s*@args\s*$', '') }
                if ($body) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::Replace($t.Extent.StartOffset, $t.Extent.Text.Length, $body)
                }
                break
            }
        }
    }
}

# ~~~~~~~~~~~~~~~~~~ fzf (fzf + fzf-tab) ~~~~~~~~~~~~~~~~~~~
# PSFzf supplies history/file pickers. Its Tab preview ignores completion
# tooltips, so our Tab handler passes those to a separate preview process.
function Initialize-Completions {
    $originalPrompt = $function:prompt
    try { Import-Module posh-git -ErrorAction Stop }
    finally { Set-Item Function:\global:prompt -Value $originalPrompt }

    # posh-git's proxy-function support only recognizes $args, not our @args wrappers.
    $script:GitShortcutPrefixes = @{}
    Get-Command -CommandType Function | Where-Object {
        $_.ScriptBlock.File -eq (Join-Path $PSScriptRoot 'aliases.ps1')
    } | ForEach-Object {
        if ($_.Definition -match '^\s*(git(?:\s+[^;\r\n]+)?)\s+@args\s*$') {
            $script:GitShortcutPrefixes[$_.Name] = $Matches[1]
        }
    }
    if ($script:GitShortcutPrefixes.Count) {
        Register-ArgumentCompleter -Native -CommandName @($script:GitShortcutPrefixes.Keys) -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $name = $commandAst.CommandElements[0]
            $text = $commandAst.Extent.Text.PadRight($cursorPosition - $commandAst.Extent.StartOffset)
            $arguments = $text.Substring($name.Extent.EndOffset - $commandAst.Extent.StartOffset)
            Expand-GitCommand ($script:GitShortcutPrefixes[$name.Value] + $arguments)
        }
    }

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { return }

    if (Get-Module -ListAvailable PSFzf) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Alt+t' -PSReadlineChordReverseHistory 'Ctrl+r'
    }

    $script:CompletionPreview = Join-Path $PSScriptRoot 'completion-preview.ps1'
    Set-PSReadLineKeyHandler -Key Tab -BriefDescription FzfCompletion -ScriptBlock {
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)
        $completion = Get-ShellCompletion $line $cursor
        $matches = @($completion.CompletionMatches)
        if (-not $matches.Count) { return }
        $selected = $matches[0]
        if ($matches.Count -gt 1) {
            $dataPath = [IO.Path]::GetTempFileName()
            try {
                $matches | Select-Object CompletionText, ToolTip, ResultType | ConvertTo-Json -Depth 3 |
                    Set-Content -LiteralPath $dataPath -Encoding utf8
                $preview = 'pwsh -NoLogo -NoProfile -File "{0}" -DataPath "{1}" -Index {{1}}' -f $script:CompletionPreview, $dataPath
                $items = for ($i = 0; $i -lt $matches.Count; $i++) {
                    "{0}`t{1}" -f $i, $matches[$i].ListItemText
                }
                $choice = $items | fzf --layout=reverse --delimiter='\t' --with-nth='2..' `
                    --preview $preview --preview-window=right:50% --bind=tab:down,shift-tab:up
                if ($LASTEXITCODE -in 1, 130) { return }
                if ($LASTEXITCODE -ne 0) { throw "fzf completion failed (exit $LASTEXITCODE)" }
                $selected = $matches[[int]($choice -split "`t", 2)[0]]
            }
            finally {
                Remove-Item -LiteralPath $dataPath
                Invoke-CompletionPrompt
            }
        }
        [Microsoft.PowerShell.PSConsoleReadLine]::Replace($completion.ReplacementIndex, $completion.ReplacementLength, $selected.CompletionText)
    }

    # Keep built-in path completion. The preview process lists only the selected
    # directory, rather than launching eza for every candidate before fzf opens.
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName z -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $words = @($commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
            zoxide query --list -- @words 2>$null | Select-Object -First 30 | ForEach-Object {
                $q = "'" + $_.Replace("'", "''") + "'"
                [System.Management.Automation.CompletionResult]::new($q, $_, 'ProviderContainer', $_)
            }
        }
    }
}
