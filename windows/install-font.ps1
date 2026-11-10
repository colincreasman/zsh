# The winget font MSI requires machine scope. Register the upstream font for
# this user instead, so shell setup doesn't need administrator privileges.
$ErrorActionPreference = 'Stop'
$fontDir = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$fontNames = 'Light', 'Regular', 'Bold', 'Italic', 'BoldItalic' |
    ForEach-Object { "JetBrainsMonoNLNerdFontMono-$_.ttf" }
$missing = @($fontNames | Where-Object { -not (Test-Path (Join-Path $fontDir $_)) })
if (-not $missing.Count) { return }

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
    $zip = Join-Path $tempDir 'font.zip'
    Invoke-WebRequest 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.3.0/JetBrainsMono.zip' -OutFile $zip
    Expand-Archive -LiteralPath $zip -DestinationPath $tempDir
    New-Item -ItemType Directory -Path $fontDir -Force | Out-Null
    $fontKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts'
    New-Item -Path $fontKey -Force | Out-Null
    if (-not ('ZshConfig.Fonts' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
namespace ZshConfig {
    public static class Fonts {
        [DllImport("gdi32.dll", CharSet = CharSet.Unicode)]
        public static extern int AddFontResourceW(string path);
        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern IntPtr SendMessageTimeoutW(IntPtr hwnd, uint msg, UIntPtr wparam, IntPtr lparam, uint flags, uint timeout, out UIntPtr result);
    }
}
'@
    }
    foreach ($name in $fontNames) {
        $source = Join-Path $tempDir $name
        $dest = Join-Path $fontDir $name
        Copy-Item -LiteralPath $source -Destination $dest -Force
        New-ItemProperty -Path $fontKey -Name "$([IO.Path]::GetFileNameWithoutExtension($name)) (TrueType)" -Value $dest -PropertyType String -Force | Out-Null
        if ([ZshConfig.Fonts]::AddFontResourceW($dest) -eq 0) { throw "Could not load font: $dest" }
    }
    $result = [UIntPtr]::Zero
    [void][ZshConfig.Fonts]::SendMessageTimeoutW([IntPtr]0xffff, 0x001d, [UIntPtr]::Zero, [IntPtr]::Zero, 2, 1000, [ref]$result)
}
finally { Remove-Item -LiteralPath $tempDir -Recurse -Force }
