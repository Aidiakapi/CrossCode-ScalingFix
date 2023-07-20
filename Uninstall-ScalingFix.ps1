# Functions
function Stop-Script {
  [cmdletbinding()]
  param([string]$Message = "")

  Write-Warning $Message
  Read-Host "Execution have terminated! Press Enter to close the window"
  exit
}

Write-Host "Preparing patches..."

# Patches to apply
$Patches = @(
  [PSCustomObject]@{
    File = '.\assets\js\game.compiled.js'
    Changes = @(
      # `c` is the pixel scaling passed in the constructor of ig.System
      # When initializing, set the canvas' renderingMode to pixelated
      [PSCustomObject]@{
        Original = 'this.height=b;if(this.imageSmoothingDisabled){'
        Patched  = 'this.height=b;this.canvas.style.imageRendering="pixelated";if(this.imageSmoothingDisabled){'
      }
      # Modify the "Double" scaling mode to instead be an integer scaling mode
      [PSCustomObject]@{
        Original = 'case sc.DISPLAY_TYPE.SCALE_X2:a=c*2;b=d*2;break;'
        Patched  = 'case sc.DISPLAY_TYPE.SCALE_X2:const m=Math.max(Math.min(Math.floor(b/c),Math.floor(i/d)),1);a=c*m;b=d*m;break;'
      }
    )
    Content = $null
  }
  [PSCustomObject]@{
    File = '.\assets\data\lang\sc\gui.en_US.json'
    Changes = @(
      # Rename the "Double" scaling mode to "Integer"
      [PSCustomObject]@{
        Original = '"display-type":{"name":"Display Type","group":["Original","Double","Fit","Stretch"]'
        Patched  = '"display-type":{"name":"Display Type","group":["Original","Integer","Fit","Stretch"]'
      }
    )
    Content = $null
  }
)

Write-Host "Verifying files..."

# Pre-patch checks...
ForEach ($Patch in $Patches)
{
  If((Test-Path -Path $Patch.File) -eq $false)
  {
    Stop-Script "One or more of the required files were not found. Verify the script is being run in the game folder."
  } else {
    
    Write-Host "Reading file contents..."
    $Patch.Content = Get-Content -Path $Patch.File -Raw

    if($Patch.Content)
    {
      ForEach ($Change in $Patch.Changes)
      {
        $MatchesFound = ($Patch.Content -split $Change.Patched, 0, "simplematch" | Measure-Object | Select-Object -Exp Count) - 1
        if($MatchesFound -ne 1)
        {
          Stop-Script "Expected 1 match but found $MatchesFound, in file '$($Patch.File)', for line:
          $($Change.Patched)" 
        }
      }
    } else {
      Stop-Script "The file was empty."
    }
  }
}

# Everything looks fine, let's patch the files!
ForEach ($Patch in $Patches)
{
  Write-Host "Applying patches to " $Patch.File "..."

  ForEach ($Change in $Patch.Changes)
  {
    $Patch.Content = $Patch.Content -replace [regex]::escape($Change.Patched), $Change.Original
  }
  
  $Patch.Content | Set-Content -Path $Patch.File
}

Write-Host "Patching is complete. Press Enter to exit the script."
Read-Host
