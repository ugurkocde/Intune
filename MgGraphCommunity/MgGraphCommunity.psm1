#Requires -Version 7.0

# Module root: dot-sources Private (load order matters) and Public (autodetect).
# Only Public functions are exported via the manifest.

$ErrorActionPreference = 'Stop'

# In-memory connection + token cache state, scoped to the module session.
$script:MgcContext = $null
$script:MgcMemoryCache = @{}

# Load order: Common -> Cache -> State -> Sdk -> Auth -> Public
$privateFolders = @('Common','Cache','State','Sdk','Auth')
foreach ($folder in $privateFolders) {
    $path = Join-Path $PSScriptRoot "Private/$folder"
    if (Test-Path $path) {
        Get-ChildItem -Path $path -Filter '*.ps1' -File |
            Sort-Object Name |
            ForEach-Object { . $_.FullName }
    }
}

$publicPath = Join-Path $PSScriptRoot 'Public'
$publicFiles = @()
if (Test-Path $publicPath) {
    $publicFiles = Get-ChildItem -Path $publicPath -Filter '*.ps1' -File | Sort-Object Name
    foreach ($f in $publicFiles) { . $f.FullName }
}

Export-ModuleMember -Function ($publicFiles | ForEach-Object { $_.BaseName })
