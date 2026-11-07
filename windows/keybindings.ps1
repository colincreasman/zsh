# keybindings.ps1 - PSReadLine / fzf / completion setup. Twin of the ZLE half of
# zsh/functions.zsh (setkeybindings, fzfinit) plus the autosuggest/highlight
# styling from home/.zshrc.
# Needs PowerShell 7 and PSReadLine 2.2+ for inline suggestions; install.ps1 sets that up.

$script:Esc = [char]27

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
        try { Set-PSReadLineOption -ErrorAction Stop @setting } catch {}
    }

    # ~~~~~~~~~~~~~~~~~~ Syntax highlighting (zsh-syntax-highlighting) ~~~~~~~~~~~~~~~~~~~
    # Same xterm-256 numbers as ZSH_HIGHLIGHT_STYLES / ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE.
    $fg = { param($n, $extra = '') '{0}[38;5;{1}{2}m' -f $script:Esc, $n, $extra }
    try {
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
    } catch {}

    # ~~~~~~~~~~~~~~~~~~ Key bindings ~~~~~~~~~~~~~~~~~~~
    # Up/Down browse history filtered by what's typed (zsh: ghost-text history).
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Ctrl+Space accepts the whole suggestion, Alt+Space one word.
    try { Set-PSReadLineKeyHandler -Chord 'Ctrl+Spacebar' -Function AcceptSuggestion } catch {}
    try { Set-PSReadLineKeyHandler -Chord 'Alt+Spacebar' -Function AcceptNextSuggestionWord } catch {}

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
# PSFzf gives Ctrl+R (fzf over history), Ctrl+T (file picker) and fzf Tab
# completion; the preview pane shows each candidate's tooltip, which we fill
# with the same eza listing the Mac's fzf-tab previews use.
function Initialize-Completions {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) { return }

    if (Get-Module -ListAvailable PSFzf) {
        Import-Module PSFzf
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r' `
            -TabExpansion -TabCompletionPreviewWindow 'right'
    }

    $listing = { param($path)
        if (Get-Command eza -ErrorAction SilentlyContinue) {
            eza -1a --group-directories-first --classify --sort=name --color=never -- $path 2>$null | Out-String
        }
        else { (Get-ChildItem -Force -LiteralPath $path -ErrorAction SilentlyContinue | ForEach-Object Name) -join "`n" }
    }
    $script:EzaListing = $listing

    # Commands that take a path: complete files, with a directory listing as preview.
    # Cmdlets (and their aliases cd/cat/rm/mv/cp) bind by -Path; anything else is
    # treated as a native command that just receives words.
    $pathCompleter = {
        param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
        [System.Management.Automation.CompletionCompleters]::CompleteFilename($wordToComplete) | ForEach-Object {
            $tip = if ($_.ResultType -eq 'ProviderContainer') { & $script:EzaListing ($_.CompletionText.Trim("'")) } else { $_.ToolTip }
            if (-not $tip) { $tip = $_.CompletionText }
            [System.Management.Automation.CompletionResult]::new($_.CompletionText, $_.ListItemText, $_.ResultType, $tip)
        }
    }
    $script:PathCompleter = $pathCompleter
    Register-ArgumentCompleter -ParameterName Path -ScriptBlock $pathCompleter -CommandName `
        'Set-Location', 'Get-ChildItem', 'Get-Content', 'Remove-Item', 'Move-Item', 'Copy-Item', 'New-Item', 'mkdir'
    Register-ArgumentCompleter -Native -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        & $script:PathCompleter $null $null $wordToComplete $commandAst $null
    } -CommandName 'ls', 'eza', 'find', 'tail', 'chmod', 'sh'

    # z<Tab>: offer zoxide's own ranked matches, previewing each directory.
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Register-ArgumentCompleter -Native -CommandName z -ScriptBlock {
            param($wordToComplete, $commandAst, $cursorPosition)
            $words = @($commandAst.CommandElements | Select-Object -Skip 1 | ForEach-Object { $_.ToString() })
            zoxide query --list -- @words 2>$null | Select-Object -First 30 | ForEach-Object {
                $q = if ($_ -match '\s') { "'$_'" } else { $_ }
                $tip = & $script:EzaListing $_
                if (-not $tip) { $tip = $_ }
                [System.Management.Automation.CompletionResult]::new($q, $_, 'ParameterValue', $tip)
            }
        }
    }
}
