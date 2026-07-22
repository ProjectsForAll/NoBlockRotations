#Requires -Version 5.1
<#
.SYNOPSIS
  Build NoBlockRotations packs and upload each Minecraft version to Modrinth.

.DESCRIPTION
  Uses the current git commit hash as the pack version. Builds
  dist/NoBlockRotations-<mc>-<hash>.zip via Build-Packs.ps1, then creates one
  Modrinth version per zip (loaders: minecraft).

.PARAMETER Token
  Modrinth personal access token (VERSION_CREATE scope).

.PARAMETER ProjectId
  Modrinth project ID or slug.

.PARAMETER VersionType
  release | beta | alpha (default: release).

.PARAMETER Changelog
  Changelog markdown for every uploaded version.

.PARAMETER SkipBuild
  Upload existing dist zips for this git hash without rebuilding.

.PARAMETER DryRun
  Build (unless -SkipBuild) and print upload payloads; do not call the API.

.PARAMETER McVersion
  Upload a single Minecraft version only (e.g. 1.21.4).

.EXAMPLE
  .\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId AABBCCDD

.EXAMPLE
  .\Publish-Modrinth.ps1 -Token $env:MODRINTH_TOKEN -ProjectId no-block-rotations -McVersion 1.21.10 -DryRun
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Token,

    [Parameter(Mandatory = $true)]
    [string] $ProjectId,

    [ValidateSet('release', 'beta', 'alpha')]
    [string] $VersionType = 'release',

    [string] $Changelog = 'Automated upload from git.',

    [switch] $SkipBuild,

    [switch] $DryRun,

    [string] $McVersion
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = $PSScriptRoot
$DistDir = Join-Path $Root 'dist'
$BuildScript = Join-Path $Root 'Build-Packs.ps1'
$ApiBase = 'https://api.modrinth.com/v2'
$UserAgent = 'ProjectsForAll/NoBlockRotations (https://github.com/ProjectsForAll/NoBlockRotations)'

function Normalize-ModrinthToken {
    param([string] $Raw)

    $t = $Raw.Trim().Trim('"').Trim("'")
    if ($t -match '^(?i)Bearer\s+(.+)$') {
        $t = $Matches[1].Trim()
    }
    if ([string]::IsNullOrWhiteSpace($t)) {
        throw 'Modrinth token is empty after trimming.'
    }
    return $t
}

function Get-ModrinthHeaders {
    param([string] $AuthToken)
    return @{
        'User-Agent'    = $UserAgent
        'Authorization' = $AuthToken
    }
}

function Test-ModrinthAuth {
    param([string] $AuthToken)

    try {
        $user = Invoke-RestMethod -Method Get -Uri "$ApiBase/user" -Headers (Get-ModrinthHeaders -AuthToken $AuthToken)
    } catch {
        $status = $null
        $body = $_.Exception.Message
        if ($_.Exception.Response) {
            $status = [int]$_.Exception.Response.StatusCode
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                $body = $reader.ReadToEnd()
                $reader.Dispose()
            } catch { }
        }

        if ($status -eq 401 -or $status -eq 403 -or $body -match 'unauthorized|Invalid Authentication') {
            throw @"
Modrinth authentication failed$(if ($status) { " (HTTP $status)" }).

$body

Fix:
  1. Create a personal access token at https://modrinth.com/settings/account
  2. Enable at least the VERSION_CREATE scope (missing scopes also return 401)
  3. Pass the raw token only (starts with mrp_) - do not wrap it in Bearer
  4. Example:
       `$env:MODRINTH_TOKEN = 'mrp_...'
       .\Publish-Modrinth.ps1 -Token `$env:MODRINTH_TOKEN -ProjectId YOUR_ID
"@
        }
        throw "Modrinth /user check failed: $body"
    }

    Write-Host "Authenticated as $($user.username) ($($user.id))"
    return $user
}

function Get-GitPackVersion {
    Push-Location $Root
    try {
        $hash = (git rev-parse --short HEAD 2>$null)
        if (-not $hash) { throw 'Not a git repository (or git is unavailable).' }
        $hash = $hash.Trim()
        $dirty = (git status --porcelain 2>$null)
        if ($dirty) {
            Write-Warning 'Working tree is dirty; packing version will include .dirty suffix.'
            return "$hash.dirty"
        }
        return $hash
    } finally {
        Pop-Location
    }
}

function Get-ModrinthGameVersions {
    $response = Invoke-RestMethod -Method Get -Uri "$ApiBase/tag/game_version" -Headers @{
        'User-Agent' = $UserAgent
    }
    return @($response | ForEach-Object { $_.version })
}

function Resolve-ModrinthGameVersions {
    param(
        [string] $Mc,
        [string[]] $Available
    )

    if ($Available -contains $Mc) {
        return @($Mc)
    }

    # Unreleased targets (e.g. 26.3) may only have snapshot tags on Modrinth.
    $snapshotPattern = '^{0}-snapshot-(\d+)$' -f [regex]::Escape($Mc)
    $snaps = @(
        $Available |
            Where-Object { $_ -match $snapshotPattern } |
            Sort-Object {
                if ($_ -match $snapshotPattern) { [int]$Matches[1] } else { 0 }
            } -Descending
    )
    if ($snaps.Count -gt 0) {
        Write-Warning "Modrinth has no tag '$Mc'; using '$($snaps[0])' for game_versions."
        return @($snaps[0])
    }

    throw "No Modrinth game_versions tag found for Minecraft $Mc."
}

function Get-ZipMcVersion {
    param(
        [string] $FileName,
        [string] $PackVersion
    )

    # NoBlockRotations-<mc>-<packVersion>.zip
    $escaped = [regex]::Escape($PackVersion)
    if ($FileName -match "^NoBlockRotations-(.+)-$escaped\.zip$") {
        return $Matches[1]
    }
    return $null
}

function ConvertTo-ModrinthJson {
    param([hashtable] $Data)

    # Windows PowerShell 5.1's ConvertTo-Json collapses single-element arrays.
    Add-Type -AssemblyName System.Web.Extensions
    $serializer = New-Object System.Web.Script.Serialization.JavaScriptSerializer
    $serializer.MaxJsonLength = 2MB
    return $serializer.Serialize($Data)
}

function Publish-PackVersion {
    param(
        [string] $ZipPath,
        [string] $Mc,
        [string] $PackVersion,
        [string[]] $GameVersions,
        [bool] $Featured,
        [string] $AuthToken
    )

    $fileName = Split-Path -Leaf $ZipPath
    # Keep version_number unique per MC target while anchoring on the git hash.
    $versionNumber = "$PackVersion+$Mc"
    $name = "NoBlockRotations $Mc ($PackVersion)"

    $data = @{
        name           = $name
        version_number = $versionNumber
        changelog      = $Changelog
        dependencies   = @()
        game_versions  = [string[]]@($GameVersions)
        version_type   = $VersionType
        loaders        = [string[]]@('minecraft')
        featured       = $Featured
        project_id     = $ProjectId
        file_parts     = [string[]]@('file')
        primary_file   = 'file'
    }
    $dataJson = ConvertTo-ModrinthJson -Data $data

    Write-Host "Uploading $fileName -> version_number=$versionNumber game_versions=$($GameVersions -join ', ')"

    if ($DryRun) {
        Write-Host "  [dry-run] $dataJson"
        return
    }

    # Use HttpClient multipart — curl's data=<file syntax breaks under Windows PowerShell.
    Add-Type -AssemblyName System.Net.Http
    $client = $null
    $content = $null
    $fileStream = $null
    $request = $null
    try {
        $client = New-Object System.Net.Http.HttpClient
        $client.Timeout = [TimeSpan]::FromMinutes(5)

        $content = New-Object System.Net.Http.MultipartFormDataContent

        # Modrinth expects the JSON metadata as a plain form field named "data".
        $dataContent = New-Object System.Net.Http.StringContent($dataJson, [System.Text.Encoding]::UTF8)
        $content.Add($dataContent, 'data')

        $fileStream = [System.IO.File]::OpenRead($ZipPath)
        $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
        $fileContent.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse('application/zip')
        $content.Add($fileContent, 'file', $fileName)

        $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::Post, "$ApiBase/version")
        $request.Headers.TryAddWithoutValidation('User-Agent', $UserAgent) | Out-Null
        $request.Headers.TryAddWithoutValidation('Authorization', $AuthToken) | Out-Null
        $request.Content = $content

        $response = $client.SendAsync($request).GetAwaiter().GetResult()
        $body = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $status = [int]$response.StatusCode

        if (-not $response.IsSuccessStatusCode) {
            $hint = ''
            if ($status -eq 401 -or $status -eq 403) {
                $hint = @"

Your token can read /user but cannot create versions. On https://modrinth.com/settings/account edit the PAT and enable:
  - VERSION_CREATE (required)
  - VERSION_WRITE (optional, for later edits)
Also confirm you are a member of project $ProjectId with upload permission.
"@
            }
            throw "Modrinth upload failed for $fileName (HTTP $status)`n$body$hint"
        }

        $created = $body | ConvertFrom-Json
        Write-Host "  OK id=$($created.id) https://modrinth.com/project/$ProjectId/version/$($created.id)"
    } finally {
        if ($request) { $request.Dispose() }
        if ($fileStream) { $fileStream.Dispose() }
        if ($content) { $content.Dispose() }
        if ($client) { $client.Dispose() }
    }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if (-not (Test-Path $BuildScript)) {
    throw "Build-Packs.ps1 not found at $BuildScript"
}

$Token = Normalize-ModrinthToken -Raw $Token
if ($Token -notmatch '^(?i)mrp_') {
    Write-Warning "Token does not start with 'mrp_'. Modrinth personal access tokens usually look like mrp_...."
}

$packVersion = Get-GitPackVersion
Write-Host "Pack version (git): $packVersion"
Write-Host "Project: $ProjectId"
if ($DryRun) {
    Write-Host 'Dry run enabled - no uploads will be sent.'
} else {
    # Fail fast on bad/insufficient tokens before spending time building.
    [void](Test-ModrinthAuth -AuthToken $Token)
}

if (-not $SkipBuild) {
    $buildArgs = @{
        PackVersion = $packVersion
    }
    if ($McVersion) { $buildArgs['McVersion'] = $McVersion }
    Write-Host "Building packs..."
    & $BuildScript @buildArgs
} else {
    Write-Host 'Skipping build (-SkipBuild).'
}

if (-not (Test-Path $DistDir)) {
    throw "dist/ not found. Run without -SkipBuild first."
}

$zips = @(
    Get-ChildItem -LiteralPath $DistDir -Filter "NoBlockRotations-*-$packVersion.zip" -File |
        Sort-Object Name
)
if ($McVersion) {
    $zips = @($zips | Where-Object { (Get-ZipMcVersion -FileName $_.Name -PackVersion $packVersion) -eq $McVersion })
}
if ($zips.Count -eq 0) {
    throw "No zips found in dist/ for pack version '$packVersion'."
}

$availableGameVersions = Get-ModrinthGameVersions
$newestMc = Get-ZipMcVersion -FileName $zips[-1].Name -PackVersion $packVersion

foreach ($zip in $zips) {
    $mc = Get-ZipMcVersion -FileName $zip.Name -PackVersion $packVersion
    if (-not $mc) {
        Write-Warning "Skipping unrecognized zip name: $($zip.Name)"
        continue
    }

    $gameVersions = Resolve-ModrinthGameVersions -Mc $mc -Available $availableGameVersions
    $featured = ($mc -eq $newestMc)

    Publish-PackVersion `
        -ZipPath $zip.FullName `
        -Mc $mc `
        -PackVersion $packVersion `
        -GameVersions $gameVersions `
        -Featured $featured `
        -AuthToken $Token
}

Write-Host "Finished. Uploaded $($zips.Count) version(s) for pack $packVersion."
