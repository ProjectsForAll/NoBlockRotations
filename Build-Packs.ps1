#Requires -Version 5.1
<#
.SYNOPSIS
  Generate per-Minecraft-version NoBlockRotations packs and zip them for in-game import.

.DESCRIPTION
  Writes packs/<mc-version>/ with era-correct blockstates + pack.mcmeta, then creates
  dist/NoBlockRotations-<mc-version>-<pack-version>.zip with pack.mcmeta at the zip root
  (required for Minecraft resource pack import).

.PARAMETER PackVersion
  Override the pack version from ./VERSION (e.g. 1.0.0).

.PARAMETER SkipZip
  Only regenerate packs/, do not write dist/*.zip.

.PARAMETER McVersion
  Build a single Minecraft version (e.g. 1.21.4). Default: all.
#>
[CmdletBinding()]
param(
    [string] $PackVersion,
    [switch] $SkipZip,
    [string] $McVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = $PSScriptRoot
$PacksDir = Join-Path $Root 'packs'
$DistDir = Join-Path $Root 'dist'
$PackPng = Join-Path $Root 'pack.png'
$VersionFile = Join-Path $Root 'VERSION'

if (-not $PackVersion) {
    if (-not (Test-Path $VersionFile)) { throw "VERSION file missing at $VersionFile" }
    $PackVersion = (Get-Content -LiteralPath $VersionFile -Raw).Trim()
}
if (-not (Test-Path $PackPng)) { throw "pack.png missing at $PackPng" }

# ---------------------------------------------------------------------------
# Version matrix: one entry per downloadable Minecraft target.
# Era: pre (pre-flattening), flat (1.13+).
# ModelStyle: bare | block | namespaced
# ---------------------------------------------------------------------------
$Versions = @(
    @{ Mc = '1.8'; Format = 1; Era = 'pre'; ModelStyle = 'bare'; Path = $false; Concrete = $false }
    @{ Mc = '1.9'; Format = 2; Era = 'pre'; ModelStyle = 'bare'; Path = $true;  Concrete = $false }
    @{ Mc = '1.10'; Format = 2; Era = 'pre'; ModelStyle = 'bare'; Path = $true;  Concrete = $false }
    @{ Mc = '1.11'; Format = 3; Era = 'pre'; ModelStyle = 'bare'; Path = $true;  Concrete = $false }
    @{ Mc = '1.12'; Format = 3; Era = 'pre'; ModelStyle = 'bare'; Path = $true;  Concrete = $true }
    @{ Mc = '1.13'; Format = 4; Era = 'flat'; ModelStyle = 'block'; Path = $true;  Concrete = $true; PathName = 'grass_path' }
    @{ Mc = '1.14'; Format = 4; Era = 'flat'; ModelStyle = 'block'; Path = $true;  Concrete = $true; PathName = 'grass_path' }
    @{ Mc = '1.15'; Format = 5; Era = 'flat'; ModelStyle = 'block'; Path = $true;  Concrete = $true; PathName = 'grass_path' }
    @{ Mc = '1.16'; Format = 5; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'grass_path' }
    @{ Mc = '1.16.2'; Format = 6; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'grass_path' }
    @{ Mc = '1.17'; Format = 7; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.18'; Format = 8; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.19'; Format = 9; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.19.3'; Format = 12; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.19.4'; Format = 13; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20'; Format = 15; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20.2'; Format = 18; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20.3'; Format = 22; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20.4'; Format = 22; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20.5'; Format = 32; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.20.6'; Format = 32; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21'; Format = 34; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.1'; Format = 34; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.2'; Format = 42; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.3'; Format = 42; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.4'; Format = 46; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.5'; Format = 55; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.6'; Format = 63; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.7'; Format = 64; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.8'; Format = 64; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path' }
    @{ Mc = '1.21.9'; Format = 69.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '1.21.10'; Format = 69.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '1.21.11'; Format = 75.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '26.1'; Format = 84.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '26.1.1'; Format = 84.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '26.1.2'; Format = 84.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '26.2'; Format = 88.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
    @{ Mc = '26.3'; Format = 93.0; Era = 'flat'; ModelStyle = 'namespaced'; Path = $true; Concrete = $true; PathName = 'dirt_path'; NewMeta = $true }
)

$ConcreteColors = @(
    'white', 'orange', 'magenta', 'light_blue', 'yellow', 'lime', 'pink', 'gray',
    'light_gray', 'cyan', 'purple', 'blue', 'brown', 'green', 'red', 'black'
)

function Get-ModelRef {
    param([string] $Name, [string] $Style)
    switch ($Style) {
        'bare' { return $Name }
        'block' { return "block/$Name" }
        'namespaced' { return "minecraft:block/$Name" }
        default { throw "Unknown ModelStyle: $Style" }
    }
}

function New-RotatedVariantsJson {
    param(
        [string] $Model,
        [string] $VariantKey,
        [int] $Indent = 4
    )
    $pad = ' ' * $Indent
    $pad2 = ' ' * ($Indent + 2)
    $pad3 = ' ' * ($Indent + 4)
    $lines = @(
        "$pad`"$VariantKey`": ["
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2}"
        "$pad]"
    )
    return ($lines -join "`n")
}

function New-MirroredVariantsJson {
    param(
        [string] $Model,
        [string] $MirroredModel,
        [string] $VariantKey,
        [int] $Indent = 4
    )
    $pad = ' ' * $Indent
    $pad2 = ' ' * ($Indent + 2)
    $pad3 = ' ' * ($Indent + 4)
    $lines = @(
        "$pad`"$VariantKey`": ["
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$MirroredModel`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$Model`""
        "$pad2},"
        "$pad2{"
        "$pad3`"model`": `"$MirroredModel`""
        "$pad2}"
        "$pad]"
    )
    return ($lines -join "`n")
}

function New-SimpleBlockstate {
    param([string] $Model, [string] $VariantKey)
    $body = New-RotatedVariantsJson -Model $Model -VariantKey $VariantKey
    return "{`n  `"variants`": {`n$body`n  }`n}`n"
}

function New-MirroredBlockstate {
    param([string] $Model, [string] $MirroredModel, [string] $VariantKey)
    $body = New-MirroredVariantsJson -Model $Model -MirroredModel $MirroredModel -VariantKey $VariantKey
    return "{`n  `"variants`": {`n$body`n  }`n}`n"
}

function New-SnowyBlockstate {
    param(
        [string] $Model,
        [string] $SnowModel,
        [string] $Style
    )
    $snowyFalse = New-RotatedVariantsJson -Model $Model -VariantKey 'snowy=false'
    $snowRef = Get-ModelRef -Name $SnowModel -Style $Style
    return @"
{
  "variants": {
$snowyFalse,
    "snowy=true": {
      "model": "$snowRef"
    }
  }
}
"@
}

function New-PackMcmeta {
    param(
        [string] $Mc,
        $Format,
        [bool] $NewMeta
    )
    $desc = "NoBlockRotations for Minecraft $Mc - base coordinates leaked no more!"
    if ($NewMeta) {
        # 1.21.9+ / format 65+: min_format + max_format
        $fmtJson = if ($Format -is [double] -or ("$Format" -match '\.')) {
            # Keep major.minor as JSON number (e.g. 69.0)
            '{0:0.0}' -f [double]$Format
        } else {
            "$Format"
        }
        return $(@"
{
  "pack": {
    "description": "$desc",
    "min_format": $fmtJson,
    "max_format": $fmtJson
  }
}
"@)
    }

    $fmtInt = [int][math]::Floor([double]$Format)
    return $(@"
{
  "pack": {
    "pack_format": $fmtInt,
    "description": "$desc"
  }
}
"@)
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Content)
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8)
}

function Build-Pack {
    param([hashtable] $V)

    $mc = $V.Mc
    $packRoot = Join-Path $PacksDir $mc
    $states = Join-Path $packRoot 'assets\minecraft\blockstates'

    if (Test-Path $packRoot) {
        Remove-Item -LiteralPath $packRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Path $states -Force | Out-Null

    $style = $V.ModelStyle
    $era = $V.Era
    $variantKey = if ($era -eq 'pre') { 'normal' } else { '' }
    $newMeta = $V.ContainsKey('NewMeta') -and [bool]$V['NewMeta']
    $includePath = [bool]$V['Path']
    $includeConcrete = [bool]$V['Concrete']
    $pathName = if ($V.ContainsKey('PathName') -and $V['PathName']) { $V['PathName'] } else { 'grass_path' }

    $meta = New-PackMcmeta -Mc $mc -Format $V.Format -NewMeta $newMeta
    Write-Utf8NoBom -Path (Join-Path $packRoot 'pack.mcmeta') -Content $meta
    Copy-Item -LiteralPath $PackPng -Destination (Join-Path $packRoot 'pack.png') -Force

    # Shared simple blocks
    foreach ($name in @('sand', 'red_sand', 'dirt')) {
        $model = Get-ModelRef -Name $name -Style $style
        Write-Utf8NoBom -Path (Join-Path $states "$name.json") -Content (New-SimpleBlockstate -Model $model -VariantKey $variantKey)
    }

    # Stone / bedrock keep mirrored variants (vanilla), drop Y rotations
    foreach ($pair in @(
            @{ Name = 'stone'; Mirrored = 'stone_mirrored' },
            @{ Name = 'bedrock'; Mirrored = 'bedrock_mirrored' }
        )) {
        $model = Get-ModelRef -Name $pair.Name -Style $style
        $mirrored = Get-ModelRef -Name $pair.Mirrored -Style $style
        Write-Utf8NoBom -Path (Join-Path $states "$($pair.Name).json") `
            -Content (New-MirroredBlockstate -Model $model -MirroredModel $mirrored -VariantKey $variantKey)
    }

    # Lily pad
    if ($era -eq 'pre') {
        $lilyModel = Get-ModelRef -Name 'waterlily' -Style $style
        Write-Utf8NoBom -Path (Join-Path $states 'waterlily.json') -Content (New-SimpleBlockstate -Model $lilyModel -VariantKey $variantKey)
    } else {
        $lilyModel = Get-ModelRef -Name 'lily_pad' -Style $style
        Write-Utf8NoBom -Path (Join-Path $states 'lily_pad.json') -Content (New-SimpleBlockstate -Model $lilyModel -VariantKey $variantKey)
    }

    # Grass
    if ($era -eq 'pre') {
        $grassModel = Get-ModelRef -Name 'grass_normal' -Style $style
        Write-Utf8NoBom -Path (Join-Path $states 'grass.json') `
            -Content (New-SnowyBlockstate -Model $grassModel -SnowModel 'grass_snowed' -Style $style)
    } else {
        $grassModel = Get-ModelRef -Name 'grass_block' -Style $style
        Write-Utf8NoBom -Path (Join-Path $states 'grass_block.json') `
            -Content (New-SnowyBlockstate -Model $grassModel -SnowModel 'grass_block_snow' -Style $style)
    }

    # Mycelium / podzol
    $snowName = if ($era -eq 'pre') { 'grass_snowed' } else { 'grass_block_snow' }
    foreach ($name in @('mycelium', 'podzol')) {
        $model = Get-ModelRef -Name $name -Style $style
        Write-Utf8NoBom -Path (Join-Path $states "$name.json") `
            -Content (New-SnowyBlockstate -Model $model -SnowModel $snowName -Style $style)
    }

    # Dirt / grass path
    if ($includePath) {
        $pathModel = Get-ModelRef -Name $pathName -Style $style
        Write-Utf8NoBom -Path (Join-Path $states "$pathName.json") -Content (New-SimpleBlockstate -Model $pathModel -VariantKey $variantKey)
    }

    # Concrete powder (1.12+)
    if ($includeConcrete) {
        foreach ($color in $ConcreteColors) {
            $name = "${color}_concrete_powder"
            $model = Get-ModelRef -Name $name -Style $style
            Write-Utf8NoBom -Path (Join-Path $states "$name.json") -Content (New-SimpleBlockstate -Model $model -VariantKey $variantKey)
        }
    }

    return $packRoot
}

function Compress-PackZip {
    param(
        [string] $PackRoot,
        [string] $ZipPath
    )

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    if (Test-Path $ZipPath) {
        Remove-Item -LiteralPath $ZipPath -Force
    }
    $zipDir = Split-Path -Parent $ZipPath
    if (-not (Test-Path $zipDir)) {
        New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    }

    # ZipFile.CreateFromDirectory can embed backslashes on Windows; write entries manually.
    $zip = [System.IO.Compression.ZipFile]::Open($ZipPath, [System.IO.Compression.ZipArchiveMode]::Create)
    try {
        $files = Get-ChildItem -LiteralPath $PackRoot -Recurse -File
        foreach ($file in $files) {
            $relative = $file.FullName.Substring($PackRoot.Length).TrimStart('\', '/')
            $entryName = $relative.Replace('\', '/')
            [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
                $zip,
                $file.FullName,
                $entryName,
                [System.IO.Compression.CompressionLevel]::Optimal
            )
        }
    } finally {
        $zip.Dispose()
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
$targets = $Versions
if ($McVersion) {
    $targets = @($Versions | Where-Object { $_.Mc -eq $McVersion })
    if ($targets.Count -eq 0) {
        throw "Unknown McVersion '$McVersion'. Valid: $($Versions.Mc -join ', ')"
    }
}

Write-Host "Building NoBlockRotations v$PackVersion for $($targets.Count) Minecraft version(s)..."

if (-not (Test-Path $PacksDir)) {
    New-Item -ItemType Directory -Path $PacksDir -Force | Out-Null
}

$built = @()
foreach ($v in $targets) {
    Write-Host "  pack $($v.Mc) (format $($v.Format))"
    $packRoot = Build-Pack -V $v
    $built += [pscustomobject]@{ Mc = $v.Mc; Path = $packRoot }
}

if (-not $SkipZip) {
    if (-not (Test-Path $DistDir)) {
        New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
    }

    # Remove stale zips for versions we just built
    foreach ($b in $built) {
        $zipName = "NoBlockRotations-$($b.Mc)-$PackVersion.zip"
        $zipPath = Join-Path $DistDir $zipName
        Write-Host "  zip  $zipName"
        Compress-PackZip -PackRoot $b.Path -ZipPath $zipPath
    }
}

# Refresh convenience "latest" folder (highest Mc in this build)
$latest = $built[-1]
$latestDir = Join-Path $Root 'NoBlockRotations'
if (Test-Path $latestDir) {
    Get-ChildItem -LiteralPath $latestDir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
} else {
    New-Item -ItemType Directory -Path $latestDir -Force | Out-Null
}
Copy-Item -Path (Join-Path $latest.Path '*') -Destination $latestDir -Recurse -Force
Write-Host "Latest convenience copy: NoBlockRotations/ <- $($latest.Mc)"

Write-Host "Done. Packs: $PacksDir"
if (-not $SkipZip) { Write-Host "Zips:  $DistDir" }
