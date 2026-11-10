param(
    [Parameter(Mandatory)][string]$DataPath,
    [Parameter(Mandatory)][int]$Index
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'keybindings.ps1')
$items = @(Get-Content -LiteralPath $DataPath -Raw | ConvertFrom-Json)
$item = $items[$Index]
$path = Get-CompletionPath $item.CompletionText
if (Test-Path -LiteralPath $path -PathType Container) {
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        eza -1a --group-directories-first --classify --sort=name --color=always -- $path
        exit $LASTEXITCODE
    }
    Get-ChildItem -LiteralPath $path -Force | ForEach-Object Name
}
else { $item.ToolTip }
