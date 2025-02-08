<#
.SYNOPSIS
    Extracts code blocks from an input file and saves them as script files.

.DESCRIPTION
    This script reads an input file (default: input.txt) and processes code blocks 
    marked by +++BEGIN and +++END. Each block must have the relative file path 
    as the first non-empty line in the format "Path: <relative path>". 
    All other non-empty lines (except for Markdown code block markers, i.e., lines 
    starting with "```") are interpreted as script code. 

    The complete target path is determined using the RootPath variable defined 
    in the JSON configuration file (default: config.json). If the target directory 
    does not exist, it will be created. Existing files will be overwritten.

.PARAMETER ConfigFile
    Path to the JSON configuration file (default: config.json).

.PARAMETER InputFile
    Path to the input file containing the code blocks (default: input.txt).
#>

[CmdletBinding()]
param(
    [string]$ConfigFile = "config.json",
    [string]$InputFile  = "input.txt"
)

# Function for error handling: Outputs an error message and exits the script
function Write-ErrorAndExit {
    param(
        [string]$Message
    )
    Write-Error $Message
    exit 1
}

# --- Load and validate the configuration file ---
if (-not (Test-Path $ConfigFile)) {
    Write-ErrorAndExit "The configuration file '$ConfigFile' was not found."
}

try {
    $configContent = Get-Content $ConfigFile -Raw
    $config = $configContent | ConvertFrom-Json
} catch {
    Write-ErrorAndExit "Error loading or parsing the configuration file."
}

if (-not $config.RootPath) {
    Write-ErrorAndExit "The 'RootPath' parameter is not defined in the configuration file."
}

# --- Check and read the input file ---
if (-not (Test-Path $InputFile)) {
    Write-ErrorAndExit "The input file '$InputFile' was not found."
}

try {
    $lines = Get-Content $InputFile
} catch {
    Write-ErrorAndExit "Error reading the input file '$InputFile'."
}

# --- Process the code blocks ---
$insideBlock = $false
$blockLines  = @()
$lineNumber  = 0

foreach ($line in $lines) {
    $lineNumber++
    $trimmedLine = $line.Trim()

    if ($trimmedLine -eq "+++BEGIN") {
        if ($insideBlock) {
            Write-ErrorAndExit "Error: A new code block starts before the previous one is closed (Line $lineNumber)."
        }
        $insideBlock = $true
        $blockLines  = @()
        continue
    }

    if ($trimmedLine -eq "+++END") {
        if (-not $insideBlock) {
            Write-ErrorAndExit "Error: Code block end found without a corresponding begin (Line $lineNumber)."
        }

        # Get all non-empty lines within the block
        $nonEmptyBlockLines = $blockLines | Where-Object { $_.Trim() -ne "" }
        if ($nonEmptyBlockLines.Count -eq 0) {
            Write-ErrorAndExit "Error: Code block has no content between +++BEGIN and +++END (Ending at Line $lineNumber)."
        }

        # The first non-empty line must have the format "Path: <relative path>"
        $pathLine = $nonEmptyBlockLines[0]
        if ($pathLine -notmatch "^Path:\s*(.+)$") {
            Write-ErrorAndExit "Error: The first line of the code block does not match the format 'Path: <relative path>' (at Line $lineNumber)."
        }
        $relativePath = $Matches[1].Trim()
        if ([string]::IsNullOrEmpty($relativePath)) {
            Write-ErrorAndExit "Error: No relative path specified in the code block (at Line $lineNumber)."
        }

        # The remaining non-empty lines (excluding the path line) form the code.
        # Markdown code block markers (lines starting with "```") are removed.
        $codeLines = @()
        for ($i = 1; $i -lt $nonEmptyBlockLines.Count; $i++) {
            $codeLine = $nonEmptyBlockLines[$i]
            if ($codeLine.TrimStart().StartsWith('```')) {
                continue
            }
            $codeLines += $codeLine
        }

        if ($codeLines.Count -eq 0) {
            Write-ErrorAndExit "Error: No code found in the block (at Line $lineNumber)."
        }

        # Construct the full file path
        try {
            $fullPath = Join-Path -Path $config.RootPath -ChildPath $relativePath
        } catch {
            Write-ErrorAndExit "Error: Invalid path '$relativePath'."
        }

        # Get the target directory and create it if it does not exist
        $targetDir = Split-Path $fullPath -Parent
        if (-not (Test-Path $targetDir)) {
            try {
                New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
            } catch {
                Write-ErrorAndExit "Error creating directory '$targetDir'."
            }
        }

        # Write the extracted code to the target file (overwrite if it exists)
        try {
            $codeLines | Out-File -FilePath $fullPath -Encoding UTF8 -Force
            Write-Host "Successfully saved: $fullPath"
        } catch {
            Write-ErrorAndExit "Error writing to file '$fullPath'."
        }

        # Reset block status
        $insideBlock = $false
        continue
    }

    # If inside a code block, collect all lines
    if ($insideBlock) {
        $blockLines += $line
    }
}

# If the script ends with an unclosed code block, report an error
if ($insideBlock) {
    Write-ErrorAndExit "Error: A code block was not properly closed with +++END."
}
