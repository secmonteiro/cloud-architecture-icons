[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$OutputPath,
    [string]$CategoryOutputDirectory,
    [switch]$SkipCategoryLibraries,
    [int]$MaxIconSize = 64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = (Resolve-Path $SourceRoot).Path.TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $repoRoot 'cloud-architecture-icons.xml'
}

if ([string]::IsNullOrWhiteSpace($CategoryOutputDirectory)) {
    $CategoryOutputDirectory = Join-Path $repoRoot 'Azure\XML'
} elseif (-not [IO.Path]::IsPathRooted($CategoryOutputDirectory)) {
    $CategoryOutputDirectory = Join-Path $repoRoot $CategoryOutputDirectory
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    return $Path.Substring($Root.Length).TrimStart('\', '/')
}

function Format-CategoryName {
    param([string]$Name)

    $knownNames = @{
        'ai + machine learning' = 'AI + Machine Learning'
        'analytics' = 'Analytics'
        'app services' = 'App Services'
        'azure ecosystem' = 'Azure Ecosystem'
        'azure stack' = 'Azure Stack'
        'blockchain' = 'Blockchain'
        'compute' = 'Compute'
        'containers' = 'Containers'
        'databases' = 'Databases'
        'devops' = 'DevOps'
        'general' = 'General'
        'hybrid + multicloud' = 'Hybrid + Multicloud'
        'identity' = 'Identity'
        'integration' = 'Integration'
        'intune' = 'Intune'
        'iot' = 'IoT'
        'management + governance' = 'Management + Governance'
        'menu' = 'Menu'
        'migrate' = 'Migrate'
        'migration' = 'Migration'
        'mixed reality' = 'Mixed Reality'
        'mobile' = 'Mobile'
        'monitor' = 'Monitor'
        'networking' = 'Networking'
        'new icons' = 'New Icons'
        'other' = 'Other'
        'security' = 'Security'
        'storage' = 'Storage'
        'web' = 'Web'
    }

    $key = $Name.ToLowerInvariant()

    if ($knownNames.ContainsKey($key)) {
        return $knownNames[$key]
    }

    $text = ($Name -replace '[-_]+', ' ' -replace '\s+', ' ').Trim()
    return [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($text.ToLowerInvariant())
}

function Format-IconName {
    param([string]$FileName)

    $name = [IO.Path]::GetFileNameWithoutExtension($FileName)
    $name = $name -replace '^\d+-icon-service-', ''
    $name = $name -replace '^\d+-icon-generic-', ''
    $name = $name -replace '_scalable$', ''

    $knownNames = @{
        'AIBuilder' = 'AI Builder'
        'Agent365' = 'Agent 365'
        'CopilotStudio' = 'Copilot Studio'
        'Dataverse' = 'Dataverse'
        'Dynamics365' = 'Dynamics 365'
        'PowerApps' = 'Power Apps'
        'PowerAutomate' = 'Power Automate'
        'PowerPages' = 'Power Pages'
        'PowerPlatform' = 'Power Platform'
    }

    if ($knownNames.ContainsKey($name)) {
        return $knownNames[$name]
    }

    $name = $name -creplace '([a-z])([A-Z])', '$1 $2'
    $name = $name -replace '[-_]+', ' '
    $name = $name -replace '\s+', ' '
    $name = $name -replace '\bQn A\b', 'QnA'
    $name = $name -replace '\bIo T\b', 'IoT'
    $name = $name -replace '\bMy SQL\b', 'MySQL'
    $name = $name -replace '\bPostgre SQL\b', 'PostgreSQL'
    $name = $name -replace '\bD Do S\b', 'DDoS'
    $name = $name -replace '\bDev Ops\b', 'DevOps'
    return $name.Trim()
}

function Get-IconCategory {
    param([string]$RelativePath)

    $parts = $RelativePath -split '[\\/]'
    $iconsIndex = -1

    for ($index = 1; $index -lt $parts.Count; $index++) {
        if ($parts[$index] -eq 'Icons' -and $parts[$index - 1] -eq 'Azure_Public_Service_Icons') {
            $iconsIndex = $index
            break
        }
    }

    if ($iconsIndex -ge 0 -and ($iconsIndex + 1) -lt $parts.Count) {
        return 'Azure Public Service Icons / ' + (Format-CategoryName $parts[$iconsIndex + 1])
    }

    if ($RelativePath -like '*Dynamics-365-icons-scalable*') {
        if ($RelativePath -like '*Dynamics 365 App Icons*') {
            return 'Dynamics 365 / App Icons'
        }

        if ($RelativePath -like '*Dynamics 365 Product Family Icons*') {
            return 'Dynamics 365 / Product Family'
        }

        return 'Dynamics 365'
    }

    if ($RelativePath -like '*Power-Platform-icons-scalable*') {
        return 'Power Platform'
    }

    if ($RelativePath -like '*Microsoft Entra architecture icons - Oct 2023*') {
        if ($RelativePath -like '*Microsoft Entra color icons SVG*') {
            return 'Microsoft Entra / Color Icons'
        }

        if ($RelativePath -like '*Microsoft Entra BW icons SVG*') {
            return 'Microsoft Entra / BW Icons'
        }

        return 'Microsoft Entra'
    }

    $directories = $parts[0..([Math]::Max(0, $parts.Count - 2))]
    return ($directories | ForEach-Object { Format-CategoryName $_ }) -join ' / '
}

function Get-SafeFileName {
    param([string]$Name)

    $invalidCharacters = [IO.Path]::GetInvalidFileNameChars()
    $safeCharacters = $Name.ToCharArray() | ForEach-Object {
        if ($invalidCharacters -contains $_) {
            '-'
        } else {
            $_
        }
    }

    return ((-join $safeCharacters) -replace '\s+', ' ').Trim()
}

function Get-LibraryFileName {
    param([string]$Category)

    $azurePrefix = 'Azure Public Service Icons / '

    if ($Category.StartsWith($azurePrefix, [StringComparison]::Ordinal)) {
        return Get-SafeFileName ("Azure - " + $Category.Substring($azurePrefix.Length) + '.xml')
    }

    return Get-SafeFileName (($Category -replace ' / ', ' - ') + '.xml')
}

function ConvertTo-DrawioLibraryXml {
    param([object[]]$Items)

    $libraryItems = @($Items | Sort-Object title | ForEach-Object {
        [ordered]@{
            data = $_.data
            w = $_.w
            h = $_.h
            aspect = $_.aspect
            title = $_.title
        }
    })

    $json = ConvertTo-Json -InputObject $libraryItems -Depth 5 -Compress
    $escapedJson = [Security.SecurityElement]::Escape($json)
    return "<?xml version=`"1.0`" encoding=`"UTF-8`"?>`n<mxlibrary>$escapedJson</mxlibrary>`n"
}

function Get-NumberFromText {
    param([string]$Value)

    if ($Value -match '[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?') {
        return [double]::Parse($Matches[0], [Globalization.CultureInfo]::InvariantCulture)
    }

    return $null
}

function Get-SvgAttribute {
    param(
        [string]$Svg,
        [string]$Attribute
    )

    $pattern = "\b$Attribute\s*=\s*['`"]([^'`"]+)['`"]"

    if ($Svg -match $pattern) {
        return $Matches[1]
    }

    return $null
}

function Get-SvgDrawioSize {
    param(
        [string]$Svg,
        [int]$MaxSize
    )

    $width = $null
    $height = $null
    $viewBox = Get-SvgAttribute $Svg 'viewBox'

    if ($null -ne $viewBox) {
        $numbers = [regex]::Matches($viewBox, '[-+]?(?:\d*\.)?\d+(?:[eE][-+]?\d+)?') |
            ForEach-Object { [double]::Parse($_.Value, [Globalization.CultureInfo]::InvariantCulture) }

        if ($numbers.Count -ge 4) {
            $width = [Math]::Abs($numbers[2])
            $height = [Math]::Abs($numbers[3])
        }
    }

    if ($null -eq $width -or $null -eq $height -or $width -le 0 -or $height -le 0) {
        $width = Get-NumberFromText (Get-SvgAttribute $Svg 'width')
        $height = Get-NumberFromText (Get-SvgAttribute $Svg 'height')
    }

    if ($null -eq $width -or $null -eq $height -or $width -le 0 -or $height -le 0) {
        $width = 1
        $height = 1
    }

    $scale = $MaxSize / [Math]::Max($width, $height)

    return [ordered]@{
        w = [Math]::Max(1, [Math]::Round($width * $scale, 2))
        h = [Math]::Max(1, [Math]::Round($height * $scale, 2))
    }
}

$svgFiles = Get-ChildItem -Path $repoRoot -Recurse -File -Filter '*.svg' |
    Sort-Object FullName

if ($svgFiles.Count -eq 0) {
    throw "No SVG files were found under $repoRoot."
}

$entries = foreach ($file in $svgFiles) {
    $relativePath = Get-RelativePath $repoRoot $file.FullName
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $svgText = [Text.Encoding]::UTF8.GetString($bytes)
    $size = Get-SvgDrawioSize $svgText $MaxIconSize
    $category = Get-IconCategory $relativePath
    $name = Format-IconName $file.Name

    [pscustomobject][ordered]@{
        Category = $category
        data = 'data:image/svg+xml;base64,' + [Convert]::ToBase64String($bytes)
        w = $size.w
        h = $size.h
        aspect = 'fixed'
        title = $name
    }
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
$libraryXml = ConvertTo-DrawioLibraryXml $entries
[IO.File]::WriteAllText($OutputPath, $libraryXml, $utf8NoBom)

Write-Host "Generated $OutputPath with $($entries.Count) icons."

if (-not $SkipCategoryLibraries) {
    New-Item -ItemType Directory -Force -Path $CategoryOutputDirectory | Out-Null

    Get-ChildItem -LiteralPath $CategoryOutputDirectory -File -Filter '*.xml' |
        Remove-Item -Force

    $categoryCount = 0

    foreach ($group in ($entries | Group-Object Category | Sort-Object Name)) {
        $categoryOutputPath = Join-Path $CategoryOutputDirectory (Get-LibraryFileName $group.Name)
        $categoryXml = ConvertTo-DrawioLibraryXml $group.Group
        [IO.File]::WriteAllText($categoryOutputPath, $categoryXml, $utf8NoBom)
        Write-Host "Generated $categoryOutputPath with $($group.Count) icons."
        $categoryCount++
    }

    Write-Host "Generated $categoryCount categorized libraries in $CategoryOutputDirectory."
}
