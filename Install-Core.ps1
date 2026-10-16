# Valy Launcher install engine. Used by the Setup wizard (.exe) and by the colorful console installer.
param([string]$Action='',[string]$Dir='',[int]$Desktop=1,[int]$StartMenu=1,[int]$Startup=1,[int]$RunAfter=1,[string]$LicenseFile='',[string]$PackageFile='',[int]$WipeData=0,[int]$WipePlugins=0,[int]$KeepLicense=1,[int]$NoLaunch=0)
$ErrorActionPreference='Stop'
$script:NoLaunchFlag=[bool]$NoLaunch
$Here=$PSScriptRoot
$Data=''
function Set-Data([string]$d){ $script:Data=Join-Path $d 'data' }
$Reg='HKCU:\Software\ValyLauncher'
$RunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$Uns='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ValyLauncher'

. (Join-Path $PSScriptRoot 'valy-premium.ps1')   # Get-MachineId, Open-Premium, Install-PremiumFiles
function Is-Premium{ $f=Join-Path $Data 'premium.valylic'; $pub=Join-Path $Here 'valy-pub.xml'; if(-not(Test-Path $pub)){ $pub=Join-Path (Get-InstallDir) 'system\valy-pub.xml' }; return [bool](Open-Premium $f $pub) }
function Get-InstallDir{
  try{ $v=[string](Get-ItemProperty $Reg -Name InstallDir -ErrorAction Stop).InstallDir; if($v -and (Test-Path -LiteralPath $v)){ return $v } }catch{}
  # no (or stale) registry entry, e.g. an install that was cut short: use the folder this script lives in (...\system) and register it again
  try{
    $p=Split-Path -Parent $Here
    if($p -and (Test-Path -LiteralPath (Join-Path $p 'system\valy-helper.ps1'))){
      New-Item -Path $Reg -Force | Out-Null; Set-ItemProperty -Path $Reg -Name InstallDir -Value $p
      return $p
    }
  }catch{}
  return ''
}
function App-Name([bool]$p){ if($p){ 'Valy Launcher Premium' } else { 'Valy Launcher' } }

# Writes a .lnk. First the normal WScript.Shell way (each property on its own); if that fails, a direct IShellLink call. Returns '' when the file exists, else the error text.
function Write-Lnk([string]$path,[string]$target,[string]$work,[string]$icon,[string]$desc){
  $err=''
  try{
    $sh=New-Object -ComObject WScript.Shell; $l=$sh.CreateShortcut($path)
    $l.TargetPath=$target
    if($work){ try{ $l.WorkingDirectory=$work }catch{} }
    if($icon -and (Test-Path -LiteralPath $icon)){ try{ $l.IconLocation=($icon+',0') }catch{} }
    if($desc){ try{ $l.Description=$desc }catch{} }
    $l.Save()
    if(Test-Path -LiteralPath $path){ return '' }
  }catch{ $err=$_.Exception.Message }
  try{
    if(-not ('Valy.Lnk' -as [type])){
      Add-Type -TypeDefinition @'
using System; using System.Text; using System.Runtime.InteropServices;
namespace Valy {
  [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class ShellLinkCo {}
  [ComImport, InterfaceType(ComInterfaceType.InterfaceIsIUnknown), Guid("000214F9-0000-0000-C000-000000000046")]
  interface IShellLinkW {
    void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c, IntPtr fd, int fl);
    void GetIDList(out IntPtr p); void SetIDList(IntPtr p);
    void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c);
    void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string s);
    void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c);
    void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string s);
    void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c);
    void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string s);
    void GetHotkey(out short h); void SetHotkey(short h);
    void GetShowCmd(out int s); void SetShowCmd(int s);
    void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder f, int c, out int i);
    void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string f, int i);
    void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string s, int r);
    void Resolve(IntPtr h, int f);
    void SetPath([MarshalAs(UnmanagedType.LPWStr)] string s);
  }
  public static class Lnk {
    public static void Make(string path, string target, string work, string icon, string desc) {
      IShellLinkW l = (IShellLinkW)new ShellLinkCo();
      l.SetPath(target);
      if (!string.IsNullOrEmpty(work)) l.SetWorkingDirectory(work);
      if (!string.IsNullOrEmpty(icon)) l.SetIconLocation(icon, 0);
      if (!string.IsNullOrEmpty(desc)) l.SetDescription(desc);
      ((System.Runtime.InteropServices.ComTypes.IPersistFile)l).Save(path, true);
    }
  }
}
'@
    }
    [Valy.Lnk]::Make($path,$target,$work,$(if($icon -and (Test-Path -LiteralPath $icon)){$icon}else{''}),$desc)
    if(Test-Path -LiteralPath $path){ return '' }
    $err+=' | the shortcut file was not created'
  }catch{ $err+=' | '+$_.Exception.Message }
  return $err
}
function Get-DesktopDir{
  $d=[Environment]::GetFolderPath('DesktopDirectory'); if(-not $d){ $d=[Environment]::GetFolderPath('Desktop') }
  if(-not $d -or -not (Test-Path -LiteralPath $d)){ try{ $d=[string](Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Desktop).Desktop; $d=[Environment]::ExpandEnvironmentVariables($d) }catch{} }
  if(-not $d -or -not (Test-Path -LiteralPath $d)){ $d=Join-Path $env:USERPROFILE 'Desktop' }
  return $d
}
function Make-Shortcuts([string]$root,[bool]$prem,[bool]$desk,[bool]$menu){
  $vbs=Join-Path $root 'valy.vbs'; $ico=Join-Path $root 'icons\valy-icon.ico'; if($prem){ if(Test-Path -LiteralPath (Join-Path $root 'data\app-icon.ico')){ $ico=Join-Path $root 'data\app-icon.ico' } elseif(Test-Path -LiteralPath (Join-Path $root 'icons\valy-icon-premium.ico')){ $ico=Join-Path $root 'icons\valy-icon-premium.ico' } }
  foreach($n in 'Valy Launcher','Valy Launcher Premium'){
    foreach($d in @((Get-DesktopDir),[Environment]::GetFolderPath('Programs'))){ if(-not $d){ continue }; Remove-Item -LiteralPath (Join-Path $d ($n+'.lnk')) -Force -ErrorAction SilentlyContinue }
  }
  $nm=App-Name $prem; $dirs=@()
  if($desk){ $dirs+=(Get-DesktopDir) }
  if($menu){ $dirs+=[Environment]::GetFolderPath('Programs') }
  foreach($d in $dirs){
    if(-not $d){ continue }
    $ex=Join-Path $root 'ValyLauncher.exe'
    if(-not (Test-Path -LiteralPath $ex)){ $ex=Join-Path $env:WINDIR 'System32\wscript.exe' }
    $er=Write-Lnk (Join-Path $d ($nm+'.lnk')) $ex $root $ico $nm
    if($er){ Write-Output ('WARN|shortcut in '+$d+' failed: '+$er); try{ Add-Content -LiteralPath (Join-Path $env:TEMP 'ValySetup-shortcut.log') -Value ((Get-Date).ToString('s')+'  '+$d+'  '+$er) }catch{} }
  }
}
function Stop-Bridge{ $bf=Join-Path $Data 'bridge.json'; if(Test-Path -LiteralPath $bf){ try{ $c=Get-Content -LiteralPath $bf -Raw|ConvertFrom-Json; Stop-Process -Id $c.pid -Force -ErrorAction SilentlyContinue }catch{} } }

function Write-Manifest([string]$Dir){
  $rec=Join-Path $Data 'recovery'; if(Test-Path $rec){ Remove-Item $rec -Recurse -Force }
  $lines=@()
  Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | Where-Object{ $_.Name -notin 'manifest.sha256','premium.valylic','ValyLauncherSetup.exe','Valy-Uninstall.exe','OperatorSettings.exe.old' -and $_.FullName -notlike ($Dir.TrimEnd('\')+'\data\*') -and $_.FullName -notlike ($Dir.TrimEnd('\')+'\plugins\*') } | ForEach-Object{
    $rel=$_.FullName.Substring($Dir.TrimEnd('\').Length+1)
    $lines+=((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLower()+' *'+$rel)
    $d=Join-Path $rec $rel; $null=New-Item -ItemType Directory -Force -Path (Split-Path -Parent $d); Copy-Item -LiteralPath $_.FullName -Destination $d -Force
  }
  [IO.File]::WriteAllLines((Join-Path $Dir 'system\manifest.sha256'),$lines,(New-Object Text.UTF8Encoding($false)))
}
function Invoke-ValyInstall{
  param([string]$Dir,[bool]$Desktop,[bool]$StartMenu,[bool]$Startup,[bool]$RunAfter,[scriptblock]$On)
  $N=8; function Step($i,$t){ if($On){ & $On $i $N $t } }
  Set-Data $Dir
  Step 1 'Preparing the install folder'
  Stop-Bridge; Start-Sleep -Milliseconds 300
  $null=New-Item -ItemType Directory -Force -Path $Dir; $null=New-Item -ItemType Directory -Force -Path $Data
  Step 2 'Copying program files'
  $src=Split-Path -Parent $Here   # payload root: ValyLauncher.exe, OperatorSettings.exe, icons\, system\
  $sysDir=Join-Path $Dir 'system'; $hf=Join-Path $sysDir 'valy-launcher.html'
  if(Test-Path -LiteralPath $hf){ (Get-Item -LiteralPath $hf -Force).Attributes='Normal' }
  # tidy up: remove loose files left by the old flat layout (they now live in system\ and icons\)
  $old=Join-Path $Dir 'valy-launcher.html'; if(Test-Path -LiteralPath $old){ (Get-Item -LiteralPath $old -Force).Attributes='Normal' }
  foreach($n in 'valy-launcher.html','valy-helper.ps1','valy-premium.ps1','valy-pub.xml','package.sig','Install-Core.ps1','Artoul-Defender.ps1','About-Valy-Launcher.md','manifest.sha256','valy-icon*','valy-defender*'){ Get-ChildItem -LiteralPath $Dir -Filter $n -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue }
  $od=Join-Path $Dir 'ArtoulDefender.exe'; if(Test-Path -LiteralPath $od){ Remove-Item -LiteralPath $od -Force -ErrorAction SilentlyContinue }   # replaced by OperatorSettings.exe
  $oc=Join-Path $Dir 'config.json'; $null=New-Item -ItemType Directory -Force -Path $sysDir
  if((Test-Path -LiteralPath $oc) -and -not (Test-Path -LiteralPath (Join-Path $sysDir 'config.json'))){ Move-Item -LiteralPath $oc -Destination (Join-Path $sysDir 'config.json') -Force }
  $oe=Join-Path $Dir 'OperatorSettings.exe'
  Get-ChildItem -LiteralPath $Dir -Filter '*.old' -File -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
  if(Test-Path -LiteralPath $oe){ try{ Move-Item -LiteralPath $oe -Destination ($oe+'.old') -Force -ErrorAction Stop }catch{} }   # a running Operator Settings window can be renamed, so it can be updated from inside itself
  Get-ChildItem -LiteralPath $src -Force | ForEach-Object{ Copy-Item -LiteralPath $_.FullName -Destination $Dir -Recurse -Force }
  try{ (Get-Item -LiteralPath $hf -Force).Attributes='Hidden' }catch{}
  New-Item -Path $Reg -Force | Out-Null; Set-ItemProperty -Path $Reg -Name InstallDir -Value $Dir   # register early, so a cut-short install can still be repaired / activated
  if(-not (Test-Path (Join-Path $sysDir 'config.json'))){ '{ "browser": "chrome" }' | Set-Content -LiteralPath (Join-Path $sysDir 'config.json') -Encoding ASCII }
  Step 3 'Unblocking files'
  Get-ChildItem -LiteralPath $Dir -Recurse -File -Force | Unblock-File -ErrorAction SilentlyContinue
  Step 4 'Registering the valy:// link'
  $ico=Join-Path $Dir 'icons\valy-icon.ico'; $exe=Join-Path $Dir 'ValyLauncher.exe'
  $k='HKCU:\Software\Classes\valy'
  New-Item -Path $k -Force | Out-Null; Set-ItemProperty -Path $k -Name '(default)' -Value 'URL:Valy Launcher'
  New-ItemProperty -Path $k -Name 'URL Protocol' -Value '' -Force | Out-Null
  New-Item -Path "$k\DefaultIcon" -Force | Out-Null; Set-ItemProperty -Path "$k\DefaultIcon" -Name '(default)' -Value ('"'+$ico+'"')
  New-Item -Path "$k\shell\open\command" -Force | Out-Null
  Set-ItemProperty -Path "$k\shell\open\command" -Name '(default)' -Value ('"'+$exe+'" "%1"')
  Step 5 'Creating shortcuts'
  $prem=Is-Premium
  Make-Shortcuts $Dir $prem $Desktop $StartMenu
  Step 6 'Setting up the tray icon and Windows startup'
  if($Startup){ Set-ItemProperty -Path $RunKey -Name 'ValyLauncher' -Value ('"'+$exe+'" tray') } else { Remove-ItemProperty -Path $RunKey -Name 'ValyLauncher' -ErrorAction SilentlyContinue }
  New-Item -Path $Reg -Force | Out-Null
  Set-ItemProperty -Path $Reg -Name InstallDir -Value $Dir; Set-ItemProperty -Path $Reg -Name Desktop -Value ([int]$Desktop); Set-ItemProperty -Path $Reg -Name StartMenu -Value ([int]$StartMenu)
  New-Item -Path $Uns -Force | Out-Null
  Set-ItemProperty -Path $Uns -Name DisplayName -Value (App-Name $prem); Set-ItemProperty -Path $Uns -Name DisplayIcon -Value $(if($prem){Join-Path $Dir 'icons\valy-icon-premium.ico'}else{$ico})
  Set-ItemProperty -Path $Uns -Name Publisher -Value 'VisualC5 [LNTB017]'; Set-ItemProperty -Path $Uns -Name DisplayVersion -Value '3.2.2'
  Set-ItemProperty -Path $Uns -Name UninstallString -Value ('"'+(Join-Path $Dir 'Valy-Uninstall.exe')+'"')
  Step 7 'Creating the integrity list and recovery copy'
  Write-Manifest $Dir
  Step 8 'Finishing'
  try{ if(-not $script:NoLaunchFlag){ Start-Process -FilePath $exe -ArgumentList 'tray' }
  if($RunAfter){ Start-Sleep -Milliseconds 800; Start-Process -FilePath $exe } }catch{ Write-Output ('WARN|could not start Valy: '+$_.Exception.Message) }
}
function Invoke-ValyPremium([string]$LicFile,[scriptblock]$On,[string]$DirArg=''){
  function Step($i,$t){ if($On){ & $On $i 3 $t } }
  $dir=Get-InstallDir
  # the registry entry can be missing after a cut-short install: trust the folder Operator Settings runs from
  if((-not $dir -or -not (Test-Path -LiteralPath $dir)) -and $DirArg -and (Test-Path -LiteralPath (Join-Path $DirArg 'system\valy-helper.ps1'))){ $dir=$DirArg; try{ New-Item -Path $Reg -Force | Out-Null; Set-ItemProperty -Path $Reg -Name InstallDir -Value $dir }catch{} }
  if(-not $dir -or -not (Test-Path -LiteralPath $dir)){ throw 'Valy Launcher is not installed yet. Install it first.' }
  Set-Data $dir
  Step 1 'Checking the Premium file'
  $pk=Open-Premium $LicFile (Join-Path $dir 'system\valy-pub.xml')
  if(-not $pk){ throw 'This Premium file is not valid for this PC (or it is damaged).' }
  Step 2 'Activating Valy Launcher Premium'
  Stop-Bridge; Start-Sleep -Milliseconds 300
  $null=New-Item -ItemType Directory -Force -Path $Data
  Copy-Item -LiteralPath $LicFile -Destination (Join-Path $Data 'premium.valylic') -Force
  Install-PremiumFiles $pk (Join-Path $dir 'icons')   # new premium files (icons) from the pack; the premium CODE stays encrypted and is loaded from memory
  Write-Manifest $dir
  Step 3 'Renaming shortcuts and restarting'
  $d=[bool](Get-ItemProperty $Reg -Name Desktop -ErrorAction SilentlyContinue).Desktop; $m=[bool](Get-ItemProperty $Reg -Name StartMenu -ErrorAction SilentlyContinue).StartMenu
  Make-Shortcuts $dir $true $d $m
  try{ Set-ItemProperty -Path 'HKCU:\Software\Classes\valy\DefaultIcon' -Name '(default)' -Value ('"'+(Join-Path $dir 'icons\valy-icon-premium.ico')+'"') }catch{}
  try{ Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-show' -WindowStyle Hidden }catch{}
  Set-ItemProperty -Path $Uns -Name DisplayName -Value 'Valy Launcher Premium' -ErrorAction SilentlyContinue; Set-ItemProperty -Path $Uns -Name DisplayIcon -Value (Join-Path $dir 'icons\valy-icon-premium.ico') -ErrorAction SilentlyContinue
  Start-Process -FilePath (Join-Path $dir 'ValyLauncher.exe') -ArgumentList 'tray'
}
function Invoke-ValyvUpdate([string]$pkg,[scriptblock]$On){
  # .valyv = encrypted + signed update bundle made by the seller (SELLER-ONLY\Make-Valyv.bat). Not readable without this engine.
  $N=5; function Step($i,$t){ if($On){ & $On $i $N $t } }
  $dir=Get-InstallDir; if(-not $dir -or -not (Test-Path -LiteralPath $dir)){ throw 'Valy Launcher is not installed on this PC. Install it first.' }
  Set-Data $dir
  Step 1 'Checking the update file'
  if(-not (Test-Path -LiteralPath $pkg)){ throw 'The update file was not found.' }
  $b=[IO.File]::ReadAllBytes($pkg)
  if($b.Length -lt 400 -or [Text.Encoding]::ASCII.GetString($b,0,6) -ne 'VALYV1'){ throw 'This is not a valid .valyv file.' }
  $sl=[BitConverter]::ToInt32($b,6); if($sl -lt 64 -or $sl -gt 1024 -or (10+$sl+16) -ge $b.Length){ throw 'The .valyv file is damaged.' }
  $sig=New-Object byte[] $sl; [Array]::Copy($b,10,$sig,0,$sl)
  $body=New-Object byte[] ($b.Length-10-$sl); [Array]::Copy($b,10+$sl,$body,0,$body.Length)
  $pub=Join-Path $Here 'valy-pub.xml'; if(-not (Test-Path -LiteralPath $pub)){ $pub=Join-Path $dir 'system\valy-pub.xml' }
  $pubXml=Get-Content -LiteralPath $pub -Raw
  $rsa=New-Object Security.Cryptography.RSACryptoServiceProvider; $rsa.FromXmlString($pubXml)
  if(-not $rsa.VerifyData($body,'SHA256',$sig)){ throw 'This .valyv file is not signed by the seller (or it was changed). Update cancelled.' }
  Step 2 'Opening the update'
  $sha=[Security.Cryptography.SHA256]::Create(); $key=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes(([regex]::Match($pubXml,'<Modulus>([^<]+)</Modulus>').Groups[1].Value)+'|valyv|1'))
  $iv=New-Object byte[] 16; [Array]::Copy($body,0,$iv,0,16)
  $aes=[Security.Cryptography.Aes]::Create(); $aes.Mode='CBC'; $aes.Padding='PKCS7'; $aes.Key=$key; $aes.IV=$iv
  $zipBytes=$aes.CreateDecryptor().TransformFinalBlock($body,16,$body.Length-16)
  $tmp=Join-Path $env:TEMP ('valyv-'+[guid]::NewGuid().ToString('N')); $null=New-Item -ItemType Directory -Force -Path $tmp
  try{
    $zf=Join-Path $tmp 'u.zip'; [IO.File]::WriteAllBytes($zf,$zipBytes)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $x=Join-Path $tmp 'x'; [IO.Compression.ZipFile]::ExtractToDirectory($zf,$x)
    $core=Join-Path $x 'payload\system\Install-Core.ps1'; if(-not (Test-Path -LiteralPath $core)){ throw 'The .valyv file has no program files.' }
    Step 3 'Closing Valy'
    foreach($pn in 'ValyLauncher','OperatorSettings','ArtoulDefender'){ if($pn -eq 'OperatorSettings' -and $env:VALY_KEEP_OP -eq '1'){ continue }; Get-Process -Name $pn -ErrorAction SilentlyContinue | ForEach-Object{ try{ $_.Kill(); $_.WaitForExit(1500)|Out-Null }catch{} } }
    Stop-Bridge; Start-Sleep -Milliseconds 400
    Step 4 'Updating all files'
    $d=[int][bool](Get-ItemProperty $Reg -Name Desktop -ErrorAction SilentlyContinue).Desktop; $m=[int][bool](Get-ItemProperty $Reg -Name StartMenu -ErrorAction SilentlyContinue).StartMenu
    $st=[int][bool](Get-ItemProperty $RunKey -Name 'ValyLauncher' -ErrorAction SilentlyContinue).ValyLauncher
    $out=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $core -Action Install -Dir $dir -Desktop $d -StartMenu $m -Startup $st -RunAfter 1
    $fail=@($out | Where-Object{ "$_" -like 'FAIL|*' })
    if($fail.Count){ throw (([string]$fail[0]).Substring(5)) }
    Step 5 'Done'
  } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}
function Invoke-ValyUninstall([scriptblock]$On,[string]$DirArg,[bool]$WipeData,[bool]$WipePlugins,[bool]$KeepLic){
  function Step($i,$t){ if($On){ & $On $i 4 $t } }
  $dir=Get-InstallDir; if((-not $dir -or -not (Test-Path -LiteralPath $dir)) -and $DirArg -and (Test-Path -LiteralPath $DirArg)){ $dir=$DirArg }; if($dir){ Set-Data $dir }
  Step 1 'Stopping Valy Launcher'; Stop-Bridge
  Step 2 'Removing shortcuts and links'
  foreach($n in 'Valy Launcher','Valy Launcher Premium'){ foreach($d in @([Environment]::GetFolderPath('Desktop'),[Environment]::GetFolderPath('Programs'))){
    $l=Join-Path $d ($n+'.lnk'); if(Test-Path -LiteralPath $l){ try{ $t=(New-Object -ComObject WScript.Shell).CreateShortcut($l); if($t.Description -like 'Valy Launcher*'){ Remove-Item -LiteralPath $l -Force -ErrorAction SilentlyContinue } }catch{} } } }
  Remove-Item -Path 'HKCU:\Software\Classes\valy' -Recurse -Force -ErrorAction SilentlyContinue
  Remove-ItemProperty -Path $RunKey -Name 'ValyLauncher' -ErrorAction SilentlyContinue
  Step 3 'Removing only the files Valy created'
  if($dir -and (Test-Path $dir)){
    $mf=Join-Path $dir 'system\manifest.sha256'; $own=@('system\manifest.sha256','ValyLauncherSetup.exe','Valy-Uninstall.exe','OperatorSettings.exe.old','system\config.json','system\valy-launcher.html')
    if(Test-Path -LiteralPath $mf){ foreach($l in Get-Content -LiteralPath $mf){ if($l -match '^[0-9a-fA-F]{64} \*(.+)$'){ $own+=$Matches[1] } } }
    if($WipePlugins){ Remove-Item -LiteralPath (Join-Path $dir 'plugins') -Recurse -Force -ErrorAction SilentlyContinue }
    foreach($r in ($own|Select-Object -Unique)){ $f=Join-Path $dir $r; if(Test-Path -LiteralPath $f -PathType Leaf){ Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue } }
    Get-ChildItem -LiteralPath $dir -Recurse -Directory -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object{ if(-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)){ Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue } }
    if(-not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)){ Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue }
  }
  Step 4 'Cleaning up'
  Remove-Item -LiteralPath $Reg -Recurse -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath $Uns -Recurse -Force -ErrorAction SilentlyContinue
  foreach($x in 'bridge.json','operator-report.txt','clear-local.flag'){ Remove-Item -LiteralPath (Join-Path $Data $x) -Force -ErrorAction SilentlyContinue }
  if(-not $KeepLic){ Remove-Item -LiteralPath (Join-Path $Data 'premium.valylic') -Force -ErrorAction SilentlyContinue }
  if($WipeData -and $Data -and (Test-Path -LiteralPath $Data)){ Get-ChildItem -LiteralPath $Data -Force -ErrorAction SilentlyContinue | Where-Object{ -not ($KeepLic -and $_.Name -eq 'premium.valylic') } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue }
  Remove-Item -LiteralPath (Join-Path $Data 'recovery') -Recurse -Force -ErrorAction SilentlyContinue
  if($dir -and (Test-Path $dir)){ Get-ChildItem -LiteralPath $dir -Recurse -Directory -Force -ErrorAction SilentlyContinue | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object{ if(-not (Get-ChildItem -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue)){ Remove-Item -LiteralPath $_.FullName -Force -ErrorAction SilentlyContinue } }; if(-not (Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue)){ Remove-Item -LiteralPath $dir -Force -ErrorAction SilentlyContinue } }
  if(-not (Get-ChildItem -LiteralPath $Data -Force -ErrorAction SilentlyContinue)){ Remove-Item -LiteralPath $Data -Force -ErrorAction SilentlyContinue }
}

if($Action){
  $cb={ param($i,$n,$t) Write-Output ("STEP|$i|$n|$t") }
  try{
    switch($Action){
      'Install'   { if(-not $Dir){ $Dir=Join-Path $env:LOCALAPPDATA 'Programs\ValyLauncher' }; Invoke-ValyInstall -Dir $Dir -Desktop ([bool]$Desktop) -StartMenu ([bool]$StartMenu) -Startup ([bool]$Startup) -RunAfter ([bool]$RunAfter) -On $cb }
      'Premium'   { Invoke-ValyPremium $LicenseFile $cb $Dir }
      'Valyv'     { Invoke-ValyvUpdate $PackageFile $cb }
      'Uninstall' { Invoke-ValyUninstall $cb $Dir ([bool]$WipeData) ([bool]$WipePlugins) ([bool]$KeepLicense) }
      'MachineId' { Write-Output ('ID|'+(Get-MachineId)) }
    }
    Write-Output 'DONE|0'
  }catch{ Write-Output ('FAIL|'+$_.Exception.Message+'  [line '+$_.InvocationInfo.ScriptLineNumber+': '+(([string]$_.InvocationInfo.Line).Trim())+']'); exit 1 }
}
