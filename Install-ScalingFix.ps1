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
        Original = 'c=c||1;this.width=a;this.height=b;'
        Patched  = 'c=1;this.canvas.style.imageRendering="pixelated";this.width=a;this.height=b;'
      }
      # This loads the setting setting for pixel scale, force it to always be 1
      [PSCustomObject]@{
        Original = 'window.IG_GAME_SCALE=(this.values[a]||0)+1;'
        Patched  = 'window.IG_GAME_SCALE=1+0*((this.values[a]||0)+1);'
      }
      # This seems to load a legacy setting that doubled the pixel count, modify
      # the string so it never matches.
      [PSCustomObject]@{
        Original = '"double-pixels"'
        Patched  = '"double-pixels__REMOVED"'
      }
      # Make a check with == sc.PIXEL_SIZE.TWO always fail
      [PSCustomObject]@{
        Original = 'var b=sc.options.get("min-sidebar")&&sc.options.get("pixel-size")==sc.PIXEL_SIZE.TWO;'
        Patched  = 'var b=false&&sc.options.get("min-sidebar")&&sc.options.get("pixel-size")==sc.PIXEL_SIZE.TWO;'
      }
      # Make a check with == sc.PIXEL_SIZE.ONE always succeed
      [PSCustomObject]@{
        Original = 'sc.options.get("pixel-size")==sc.PIXEL_SIZE.ONE'
        Patched  = '(true||sc.options.get("pixel-size")==sc.PIXEL_SIZE.ONE)'
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
        $MatchesFound = ($Patch.Content -split $Change.Original, 0, "simplematch" | Measure-Object | Select-Object -Exp Count) - 1
        if($MatchesFound -ne 1)
        {
          Stop-Script "Expected 1 match but found $MatchesFound, in file '$($Patch.File)', for line:
          $($Change.Original)"
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
    $Patch.Content = $Patch.Content -replace [regex]::escape($Change.Original), $Change.Patched
  }
  
  $Patch.Content | Set-Content -Path $Patch.File
}

Write-Host "Patching finished. Press Enter to exit the script."
Read-Host
