Write-Verbose -Verbose "Mapping tools..."
$tools    = 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\oscdimg'
Write-Verbose -Verbose "   ...oscdimg"
Start-Sleep -Milliseconds 500
$oscdimg  = "$tools\oscdimg.exe"
Write-Verbose -Verbose "   ...etfsboot"
Start-Sleep -Milliseconds 500
$etfsboot = "$tools\etfsboot.com"
Write-Verbose -Verbose "   ...efisys"
Start-Sleep -Milliseconds 500
$efisys   = "$tools\efisys.bin"

$srcIso = "C:\Users\danijel.james\Downloads\Win10_20H2_v2_English_x64.iso"
Write-Host "Mounting disk image ${SrcISO}"
Start-Sleep -Milliseconds 500
$MountISO = Mount-DiskImage -ImagePath $SrcISO -PassThru

# Get the drive letter assigned to the iso.
$IsoDriveLetter = ($MountISO | Get-Volume).DriveLetter + ':'
Write-Host -ForegroundColor Magenta "Setting drive letter to [${IsoDriveLetter}]"
Start-Sleep -Milliseconds 500

# create WimWork directory structure
New-Item -Path C:\ -ItemType Directory -Name "WimWork" -Confirm:$false -Force
"ISO","Mount","DRIVERS","MSU","Scratch" | ForEach-Object { New-Item -Path C:\WimWork -ItemType Directory -Name $_ -COnfirm:$false -Force }

# Extract the existing iso to the temporary folder
Write-Host "Extract ISO file"
$WorkSpace = "C:\WimWork\ISO"
Copy-Item $IsoDriveLetter\* $WorkSpace -Force -Recurse

# Remove the read-only attribtue from the extracted files
Write-Verbose -Verbose "Remove read-only attributes to allow editing"
Get-ChildItem $WorkSpace -Recurse | ForEach-Object { if (! $_.PsIsContainer) { $_.IsReadOnly = $false } }

# Mount the WIM image for editing
Write-Host "Mount WIM image for editing"
[string]$MountPath = "C:\WimWork\Mount"
Get-WindowsImage -ImagePath C:\WimWork\ISO\sources\install.wim                                     
[string]$MountPath = "C:\WimWork\Mount"
#Mount-WindowsImage -ImagePath C:\WimWork\ISO\sources\install.wim -Index 3 -Path $MountPath
Mount-WindowsImage -ImagePath C:\WimWork\ISO\sources\install.wim -Index 6 -Path $MountPath

# Enable NetFx3
Enable-WindowsOptionalFeature -ScratchDirectory C:\WimWork\Scratch\ -Path C:\WimWork\Mount -FeatureName "NetFx3" -Source "${IsoDriveLetter}\sources\sxs"

# Add monthly patches
Add-WindowsPackage -PackagePath \\WSPRDAPP01.corp.invocare.com.au\Source$\Applications\Microsoft\2021-02\ -Path C:\WimWork\Mount\ -PreventPending -ScratchDirectory C:\WimWork\Scratch\

# Add drivers
#Add-WindowsDriver -Path C:\WimWork\Mount\ -Driver C:\WimWork\DRIVERS -Recurse -ForceUnsigned
Add-WindowsDriver -Path C:\WimWork\Mount\ -Driver \\wsprdapp01.corp.invocare.com.au\Source$\OSD\DriverPackages\Lenovo\tc_m70tsq-m80tsq-m90tsq_w1064_20h2_202101 -Recurse -ForceUnsigned


# Remove Junk X Packages
"Microsoft.GetHelp_10.1706.13331.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.Getstarted_8.2.22942.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.Microsoft3DViewer_6.1908.2042.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.MicrosoftOfficeHub_18.1903.1152.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.MicrosoftSolitaireCollection_4.4.8204.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.MixedReality.Portal_2000.19081.1301.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.Office.OneNote_16001.12026.20112.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.People_2019.305.632.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.SkypeApp_14.53.77.0_neutral_~_kzf8qxf38zg5c",
"Microsoft.Wallet_2.4.18324.0_neutral_~_8wekyb3d8bbwe",
"microsoft.windowscommunicationsapps_16005.11629.20316.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.WindowsFeedbackHub_2019.1111.2029.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.Xbox.TCUI_1.23.28002.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.XboxApp_48.49.31001.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.XboxGameOverlay_1.46.11001.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.XboxGamingOverlay_2.34.28001.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.XboxIdentityProvider_12.50.6001.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.XboxSpeechToTextOverlay_1.17.29001.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.YourPhone_2019.430.2026.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.ZuneMusic_2019.19071.19011.0_neutral_~_8wekyb3d8bbwe",
"Microsoft.ZuneVideo_2019.19071.19011.0_neutral_~_8wekyb3d8bbwe" | ForEach-Object {
	Remove-AppxProvisionedPackage -PackageName $_ -Path "C:\WimWork\Mount\"
}





# save WIM file to source directory
Dismount-WindowsImage -Path C:\WimWork\Mount\ -Save

# create the updated iso
#[string]$CompiledISO = "C:\Users\danijel.james\Downloads\tc_m70tsq-m80tsq-m90tsq.iso"
[string]$CompiledISO = "C:\Users\danijel.james\Downloads\20H2_V2_202102.iso"
Write-Host "...write data to ${efisys}"
$data = '2#p0,e,b"{0}"#pEF,e,b"{1}"' -f $etfsboot, $efisys
Write-Host "...save data to ISO"
Start-Sleep -Milliseconds 500
Start-Process $oscdimg -Args @("-BootData:$data",'-u2','-udfver102', $WorkSpace, $CompiledISO) -Wait -NoNewWindow

# remove the extracted content
Write-Host "...remove temp WorkSpace"
Start-Sleep -Milliseconds 500
Remove-Item $WorkSpace -Recurse -Force

# dismount the iso
Write-Host "...dismount source ISO at ${SrcISO}"
Dismount-DiskImage -ImagePath $SrcISO

# Final notify
Write-Host "Compiled ISO stored at ${CompiledISO}"


