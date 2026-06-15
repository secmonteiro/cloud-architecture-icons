[CmdletBinding()]
param(
    [string]$SourceRoot,
    [string]$OutputDirectory,
    [string]$LibraryName = 'Cloud Architecture Icons',
    [string]$PackageName = 'cloud-architecture-icons',
    [int]$MaxIconSize = 64
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
}

$repoRoot = (Resolve-Path $SourceRoot).Path.TrimEnd('\', '/')

if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot 'Azure\Lucidchart'
} elseif (-not [IO.Path]::IsPathRooted($OutputDirectory)) {
    $OutputDirectory = Join-Path $repoRoot $OutputDirectory
}

function Get-RelativePath {
    param(
        [string]$Root,
        [string]$Path
    )

    return $Path.Substring($Root.Length).TrimStart('\', '/')
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

function Get-SvgLucidSize {
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
        width = [Math]::Max(1, [Math]::Round($width * $scale, 2))
        height = [Math]::Max(1, [Math]::Round($height * $scale, 2))
    }
}

function Get-Slug {
    param(
        [string]$Value,
        [int]$FallbackIndex
    )

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')

    if ([string]::IsNullOrWhiteSpace($slug)) {
        $slug = "icon-$FallbackIndex"
    }

    return $slug
}

function ConvertTo-JsonFile {
    param([object]$Value)

    return $Value | ConvertTo-Json -Depth 20
}

function New-LucidShapeDefinition {
    param(
        [string]$ImageFileName,
        [string]$ImageReference
    )

    return [ordered]@{
        locked = @('aspectRatio')
        images = [ordered]@{
            $ImageReference = [ordered]@{
                type = 'file'
                path = $ImageFileName
            }
        }
        style = [ordered]@{
            fill = [ordered]@{
                type = 'image'
                ref = $ImageReference
                mode = 'stretch'
            }
            stroke = [ordered]@{
                color = '#00000000'
                width = 1
            }
            rounding = 0
        }
        geometry = @(
            [ordered]@{
                type = 'rect'
            }
        )
    }
}

function New-ZipFromDirectoryContents {
    param(
        [string]$SourceDirectory,
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath) {
        Remove-Item -Force -LiteralPath $DestinationPath
    }

    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
    $sourceRoot = (Resolve-Path $SourceDirectory).Path.TrimEnd('\', '/')
    $zip = [System.IO.Compression.ZipFile]::Open($DestinationPath, [System.IO.Compression.ZipArchiveMode]::Create)

    try {
        Get-ChildItem -LiteralPath $sourceRoot -Recurse -File | Sort-Object FullName | ForEach-Object {
            $entryName = $_.FullName.Substring($sourceRoot.Length).TrimStart('\', '/') -replace '\\', '/'
            $entry = $zip.CreateEntry($entryName, $compressionLevel)
            $entryStream = $entry.Open()
            $fileStream = [IO.File]::OpenRead($_.FullName)

            try {
                $fileStream.CopyTo($entryStream)
            } finally {
                $fileStream.Dispose()
                $entryStream.Dispose()
            }
        }
    } finally {
        $zip.Dispose()
    }
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$buildRoot = Join-Path $OutputDirectory '_lcsl-build'
$imagesDirectory = Join-Path $buildRoot 'images'
$shapesDirectory = Join-Path $buildRoot 'shapes'

if (Test-Path -LiteralPath $buildRoot) {
    Remove-Item -Recurse -Force -LiteralPath $buildRoot
}

$svgFiles = Get-ChildItem -Path $repoRoot -Recurse -File -Filter '*.svg' |
    Where-Object { $_.FullName -notlike "$OutputDirectory*" } |
    Sort-Object FullName

if ($svgFiles.Count -eq 0) {
    throw "No SVG files were found under $repoRoot."
}

New-Item -ItemType Directory -Force -Path $imagesDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $shapesDirectory | Out-Null

$shapeEntries = New-Object System.Collections.Generic.List[object]
$usedSlugs = @{}
$index = 0

foreach ($file in $svgFiles) {
    $index++
    $name = Format-IconName $file.Name
    $baseSlug = Get-Slug $name $index
    $slug = $baseSlug

    if ($usedSlugs.ContainsKey($slug)) {
        $usedSlugs[$slug]++
        $slug = "$baseSlug-$($usedSlugs[$baseSlug])"
    } else {
        $usedSlugs[$slug] = 1
    }

    $svgText = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    $size = Get-SvgLucidSize $svgText $MaxIconSize
    $shapeId = $slug
    $imageFileName = "$slug.svg"
    $shapeFileName = "$slug.shape"
    $imageReference = 'icon'

    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $imagesDirectory $imageFileName)

    $shapeDefinition = New-LucidShapeDefinition $imageFileName $imageReference
    $shapeDefinitionJson = ConvertTo-JsonFile $shapeDefinition
    [IO.File]::WriteAllText((Join-Path $shapesDirectory $shapeFileName), $shapeDefinitionJson, (New-Object Text.UTF8Encoding($false)))

    $shapeEntries.Add([ordered]@{
        shape = $shapeId
        name = $name
        defaults = [ordered]@{
            width = $size.width
            height = $size.height
            aspectRatio = [Math]::Round($size.width / $size.height, 6)
        }
    })
}

$libraryManifest = [ordered]@{
    name = $LibraryName
    shapes = @($shapeEntries | Sort-Object { $_.name }, { $_.shape })
}

$utf8NoBom = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $buildRoot 'library.manifest'), (ConvertTo-JsonFile $libraryManifest), $utf8NoBom)

$outputFileName = "$PackageName.lcsl"
$outputPath = Join-Path $OutputDirectory $outputFileName
New-ZipFromDirectoryContents $buildRoot $outputPath

Remove-Item -Recurse -Force -LiteralPath $buildRoot

Write-Host "Generated $outputPath with $($shapeEntries.Count) Lucidchart shapes."
