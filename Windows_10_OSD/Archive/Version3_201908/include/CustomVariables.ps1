# have to move some variables for easy declaration in here...

# Basic PowerShell
# Downloading via Invoke-Webrequest is faster when not displaying progress bar!!
$ProgressPreference = 'SilentlyContinue'
#$ProgressPreference = 'Continue' # Standard

## UUP
$UUP_DUMP_URI = "https://uupdump.ml/"
$UUP_DUMP_FeatureRequestURI = "$UUP_DUMP_URI/known.php?q=feature"

# Temporary download folder.
# Make sure to add attribute "hidden".
$UUP_FolderTemp = "$env:SystemDrive\`$ROCKS.UUP"

# Aria Data Folder
$UUP_DUMP_Aria = "$UUP_FolderTemp\aria"

# UUP Download Folder
$UUP_DUMP_Aria_UUPs = "$UUP_DUMP_Aria\UUPs"
$UUP_DUMP_Aria_UUPs_Sorted = "$UUP_DUMP_Aria_UUPs\Sorted"
$UUP_DUMP_Aria_UUPs_Sorted_FODs = "$UUP_DUMP_Aria_UUPs_Sorted\FODs"
$UUP_DUMP_Aria_UUPs_Sorted_LPs = "$UUP_DUMP_Aria_UUPs_Sorted\LPs"
$UUP_DUMP_Aria_UUPs_Additional = "$UUP_DUMP_Aria_UUPs\Additional" # RSAT, FODs, etc...

# Folder for extracting aria temporary
# Using this for multiple aria versions (with UUP).
$UUP_DUMP_Temp = "$UUP_FolderTemp\temp"

# Folder for moving created and downloaded files back for user.
$UUP_DataFolder = "$PSScriptRoot\data"

# Windows
# Main system language.
# Use param to override this!
$MainLang = ([CultureInfo]::InstalledUICulture | Select-Object -First 1).Name

# ISO Mount Path
$UUP_ISOMountPath = "$UUP_FolderTemp\ROCKS.ISOFOLDER"