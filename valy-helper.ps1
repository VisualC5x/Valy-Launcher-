# Valy Launcher helper: launcher window, tray icon, System bridge, valy:// links, license check, file repair.
param([string]$Arg='',[switch]$Serve)
$ErrorActionPreference='Stop'
$Sys=$PSScriptRoot                      # ...\system   (scripts, html, keys)
$Root=Split-Path -Parent $Sys         # install folder (exe files on the first page; icons\ system\ data\)
$Icons=Join-Path $Root 'icons'
$Data=Join-Path $Root 'data'
$null=New-Item -ItemType Directory -Force -Path $Data
$BridgeFile=Join-Path $Data 'bridge.json'
$LicFile=Join-Path $Data 'premium.valylic'
. (Join-Path $PSScriptRoot 'valy-premium.ps1')   # Get-MachineId, Open-Premium (signed critical file)
$Port=47821
$G='--disable-features=msEdgeSidebarV2'
$RunKey='HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$script:Quit=$false

function Find-Exe($list){ foreach($x in $list){ if($x -and (Test-Path -LiteralPath $x)){ return $x } }; return $null }
function Get-Chrome { Find-Exe @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe","${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe","$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe") }
function Get-Edge { Find-Exe @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe","$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") }
function To-Url([string]$p){ if($p -match '^[a-zA-Z]{2,}:'){ return $p }; try{ return ([System.Uri]$p).AbsoluteUri }catch{ return 'file:///' + ($p -replace '\\','/') } }
function Start-App([string]$exe,[string]$url,[string[]]$extra=@()){ Start-Process -FilePath $exe -ArgumentList (@("--app=$url",$G)+$extra) }
function Open-Valy([string]$mode,[string]$p){
  $chrome=Get-Chrome; $edge=Get-Edge
  switch($mode){
    {$_ -in 'app','url'}   { $e=$edge; if(-not $e){$e=$chrome}; if(-not $e){throw 'No Edge/Chrome found'}; Start-App $e (To-Url $p) }
    {$_ -in 'gapp','gurl'} { $e=$chrome; if(-not $e){$e=$edge}; if(-not $e){throw 'No Chrome/Edge found'}; Start-App $e (To-Url $p) }
    'gtab' { $e=$chrome; if(-not $e){$e=$edge}; if($e){ Start-Process -FilePath $e -ArgumentList (To-Url $p) } else { Start-Process (To-Url $p) } }
    'run'  { $wd=Split-Path -Parent $p; if($wd -and (Test-Path -LiteralPath $wd)){ Start-Process -FilePath $p -WorkingDirectory $wd } else { Start-Process -FilePath $p } }
    default{ Start-Process -FilePath $p }
  }
}
function Handle-Proto([string]$a){
  if($a -notmatch '^valy://'){ return }
  $a=$a.Substring(7); $i=$a.IndexOf('/'); if($i -lt 0){ return }
  $m=$a.Substring(0,$i); $p=[uri]::UnescapeDataString($a.Substring($i+1).TrimEnd('/'))
  Open-Valy $m $p
}
function Reveal([string]$p){
  if(Test-Path -LiteralPath $p -PathType Leaf){ Start-Process explorer.exe -ArgumentList ('/select,"'+$p+'"') }
  elseif(Test-Path -LiteralPath $p){ Start-Process explorer.exe -ArgumentList ('"'+$p+'"') }
  else{ $d=Split-Path -Parent $p; if($d -and (Test-Path -LiteralPath $d)){ Start-Process explorer.exe -ArgumentList ('"'+$d+'"') } }
}
function Pick-Path([string]$kind){
  $owner=New-Object System.Windows.Forms.Form -Property @{TopMost=$true}
  try{
    if($kind -eq 'folder'){ $d=New-Object System.Windows.Forms.FolderBrowserDialog; if($d.ShowDialog($owner) -eq 'OK'){ return $d.SelectedPath } }
    else{
      $d=New-Object System.Windows.Forms.OpenFileDialog
      if($kind -eq 'exe'){ $d.Filter='Programs (*.exe;*.lnk;*.bat;*.cmd)|*.exe;*.lnk;*.bat;*.cmd|All files (*.*)|*.*' }
      elseif($kind -eq 'html'){ $d.Filter='Web files (*.html;*.htm)|*.html;*.htm|All files (*.*)|*.*' }
      else{ $d.Filter='All files (*.*)|*.*' }
      if($d.ShowDialog($owner) -eq 'OK'){ return $d.FileName }
    }
  } finally { $owner.Dispose() }
  return ''
}

# ---------- Premium license (bound to this PC, signed by the seller) ----------
$script:PkCache=$null; $script:PkStamp=''
function Get-Premium{
  try{
    if(-not (Test-Path -LiteralPath $LicFile)){ $script:PkCache=$null; $script:PkStamp=''; return $null }
    $st=(Get-Item -LiteralPath $LicFile).LastWriteTimeUtc.Ticks.ToString()
    if($script:PkStamp -ne $st){ $script:PkCache=Open-Premium $LicFile (Join-Path $Sys 'valy-pub.xml'); $script:PkStamp=$st }
    return $script:PkCache
  }catch{ return $null }
}
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
# Desktop shortcut that always uses the app icon you picked (data\app-icon.ico for Premium, else the normal Valy icon).
function Get-AppIconPath{
  $pk=Get-Premium
  if($pk){ $f=Join-Path $Data 'app-icon.ico'; if(Test-Path -LiteralPath $f){ return $f }; $p=Join-Path $Icons 'valy-icon-premium.ico'; if(Test-Path -LiteralPath $p){ return $p } }
  return (Join-Path $Icons 'valy-icon.ico')
}
# Tells Explorer the icons changed, so shortcuts show the new icon right away.
function Refresh-ShellIcons{
  try{ if(-not ('Valy.ShellN' -as [type])){ Add-Type -Namespace Valy -Name ShellN -MemberDefinition '[System.Runtime.InteropServices.DllImport("shell32.dll")] public static extern void SHChangeNotify(int e,int f,System.IntPtr a,System.IntPtr b);' } ; [Valy.ShellN]::SHChangeNotify(0x08000000,0,[IntPtr]::Zero,[IntPtr]::Zero) }catch{}
  try{ Start-Process -FilePath 'ie4uinit.exe' -ArgumentList '-show' -WindowStyle Hidden }catch{}
}
function Set-DesktopShortcut([bool]$on){
  $d=Get-DesktopDir
  $nm=$(if(Get-Premium){'Valy Launcher Premium'}else{'Valy Launcher'})
  foreach($n in 'Valy Launcher','Valy Launcher Premium'){ $p=Join-Path $d ($n+'.lnk'); if(Test-Path -LiteralPath $p){ Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } }
  if($on){
    $er=Write-Lnk (Join-Path $d ($nm+'.lnk')) (Join-Path $Root 'ValyLauncher.exe') $Root (Get-AppIconPath) $nm
    if($er){ throw ('Could not write the shortcut in '+$d+' ('+$er+')') }
  }
  try{ New-Item -Path 'HKCU:\Software\ValyLauncher' -Force | Out-Null; Set-ItemProperty -Path 'HKCU:\Software\ValyLauncher' -Name Desktop -Value ([int]$on) }catch{}
  Refresh-ShellIcons
}
# Changes the app icon everywhere (tray, shortcuts, valy:// link, Apps list). Only called after a valid Premium check.
function Apply-AppIcon([byte[]]$ico){
  $f=Join-Path $Data 'app-icon.ico'
  [IO.File]::WriteAllBytes($f,$ico)
  try{ if($script:Ni){ $ms=New-Object IO.MemoryStream(,$ico); $script:Ni.Icon=New-Object System.Drawing.Icon($ms) } }catch{}
  try{
    $sh=New-Object -ComObject WScript.Shell
    foreach($d in @((Get-DesktopDir),[Environment]::GetFolderPath('Programs'))){
      foreach($n in 'Valy Launcher Premium','Valy Launcher'){
        $p=Join-Path $d ($n+'.lnk')
        if(Test-Path -LiteralPath $p){ $l=$sh.CreateShortcut($p); if($l.Description -like 'Valy Launcher*'){ $l.IconLocation=$f+',0'; $l.Save() } }
      }
    }
  }catch{}
  try{ Set-ItemProperty -Path 'HKCU:\Software\Classes\valy\DefaultIcon' -Name '(default)' -Value ('"'+$f+'"') }catch{}
  try{ Set-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\ValyLauncher' -Name DisplayIcon -Value $f }catch{}
  Refresh-ShellIcons
}
function Get-Startup{ try{ return [bool](Get-ItemProperty -Path $RunKey -Name 'ValyLauncher' -ErrorAction Stop) }catch{ return $false } }
function Set-Startup([bool]$on){
  if($on){ Set-ItemProperty -Path $RunKey -Name 'ValyLauncher' -Value ('"'+(Join-Path $Root 'ValyLauncher.exe')+'" tray') }
  else{ Remove-ItemProperty -Path $RunKey -Name 'ValyLauncher' -ErrorAction SilentlyContinue }
}

# ---------- File check / repair ----------
function Read-Manifest{
  $mf=Join-Path $Sys 'manifest.sha256'; $r=@()
  if(Test-Path -LiteralPath $mf){ foreach($l in Get-Content -LiteralPath $mf){ if($l -match '^([0-9a-fA-F]{64}) \*(.+)$'){ $r+=,@($Matches[2],$Matches[1].ToLower()) } } }
  return $r
}
function Check-Files{
  $out=@()
  foreach($e in Read-Manifest){
    $f=Join-Path $Root $e[0]
    if(-not (Test-Path -LiteralPath $f)){ $out+=@{n=$e[0];s='missing'} }
    elseif((Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower() -ne $e[1]){ $out+=@{n=$e[0];s='bad'} }
    else{ $out+=@{n=$e[0];s='ok'} }
  }
  return $out
}
function Repair-Files{
  $list=Check-Files; $rec=Join-Path $Data 'recovery'; $url=''
  $cf=Join-Path $Sys 'config.json'
  if(Test-Path -LiteralPath $cf){ try{ $url=[string](Get-Content -LiteralPath $cf -Raw|ConvertFrom-Json).updateUrl }catch{} }
  $man=@{}; foreach($e in Read-Manifest){ $man[$e[0]]=$e[1] }
  $failed=0
  foreach($x in $list){
    if($x.s -eq 'ok'){ continue }
    $dst=Join-Path $Root $x.n; $ok=$false
    $null=New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dst)
    $src=Join-Path $rec $x.n
    if(Test-Path -LiteralPath $src){ Copy-Item -LiteralPath $src -Destination $dst -Force; $ok=$true }
    elseif($url){ try{ Invoke-WebRequest -UseBasicParsing -Uri ($url.TrimEnd('/')+'/'+($x.n -replace '\\','/')) -OutFile $dst -TimeoutSec 30; $ok=$true }catch{} }
    if($ok -and (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLower() -eq $man[$x.n]){ $x.s='fixed' } else { $failed++ }
  }
  return @{files=$list;failed=$failed}
}

# ---------- Plugins (.valyp = a zip: plugin.json, main.js, style.css, assets\*) ----------
# Only READS the plugin files (nothing is extracted or run here). The page decides which plugins are turned on.
function Get-Plugins{
  $dir=Join-Path $Root 'plugins'; $null=New-Item -ItemType Directory -Force -Path $dir
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $mime=@{png='image/png';jpg='image/jpeg';jpeg='image/jpeg';gif='image/gif';webp='image/webp';svg='image/svg+xml';mp3='audio/mpeg';ogg='audio/ogg';wav='audio/wav';m4a='audio/mp4';webm='audio/webm';json='application/json';txt='text/plain'}
  $out=@(); $total=0; $ids=@{}
  foreach($f in (Get-ChildItem -LiteralPath $dir -Filter '*.valyp' -File | Sort-Object Name)){
    $e=[ordered]@{file=$f.Name;id=$f.BaseName.ToLower();name=$f.BaseName;version='';author='';description='';icon='';iconUrl='';perms=@();main='';css='';assets=@{};hash='';error=''}
    try{
      if($f.Length -gt 12MB){ throw 'The file is bigger than 12 MB.' }
      $total+=$f.Length; if($total -gt 40MB){ throw 'Too many plugins (over 40 MB together).' }
      $e.hash=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
      $z=[IO.Compression.ZipFile]::OpenRead($f.FullName)
      try{
        $man=$null; $unz=0
        foreach($en in $z.Entries){
          $n=($en.FullName -replace '\\','/')
          if($n.EndsWith('/') -or $n.StartsWith('/') -or $n -match '(^|/)\.\.(/|$)'){ continue }
          $unz+=$en.Length; if($unz -gt 40MB){ throw 'The plugin is too big when unpacked.' }
          $isText=($n -eq 'plugin.json' -or $n -eq 'main.js' -or $n -eq 'style.css')
          $isAsset=($n -like 'assets/*')
          if(-not ($isText -or $isAsset)){ continue }
          if($isText -and $en.Length -gt 1MB){ throw ($n+' is bigger than 1 MB.') }
          if($isAsset -and $en.Length -gt 6MB){ continue }
          $ms=New-Object IO.MemoryStream; $st=$en.Open(); try{ $st.CopyTo($ms) } finally { $st.Dispose() }
          $bytes=$ms.ToArray()
          if($n -eq 'plugin.json'){ $man=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)|ConvertFrom-Json }
          elseif($n -eq 'main.js'){ $e.main=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) }
          elseif($n -eq 'style.css'){ $e.css=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF) }
          else{
            $an=$n.Substring(7); $ext=[IO.Path]::GetExtension($an).TrimStart('.').ToLower()
            if($an -match '^[A-Za-z0-9_\-\. ]+$' -and $mime.ContainsKey($ext)){ $e.assets[$an]='data:'+$mime[$ext]+';base64,'+[Convert]::ToBase64String($bytes) }
          }
        }
        if(-not $man){ throw 'plugin.json is missing.' }
        $id=([string]$man.id).ToLower()
        if($id -notmatch '^[a-z0-9][a-z0-9_.\-]{1,39}$'){ throw 'plugin.json: "id" must be 2-40 characters: a-z 0-9 . _ -' }
        if($ids.ContainsKey($id)){ throw ('Another plugin already uses the id "'+$id+'".') }
        $ids[$id]=1; $e.id=$id
        if($man.name){ $e.name=([string]$man.name).Substring(0,[Math]::Min(60,([string]$man.name).Length)) }
        $e.version=([string]$man.version); if($e.version.Length -gt 20){ $e.version=$e.version.Substring(0,20) }
        $e.author=([string]$man.author); if($e.author.Length -gt 60){ $e.author=$e.author.Substring(0,60) }
        $e.description=([string]$man.description); if($e.description.Length -gt 400){ $e.description=$e.description.Substring(0,400) }
        $ic=([string]$man.icon); if($ic.Length -gt 8){ $ic='' }
        $e.icon=$ic
        $ia=([string]$man.iconAsset); if($ia -and $e.assets.ContainsKey($ia)){ $e.iconUrl=$e.assets[$ia] }
        if($man.permissions){ $e.perms=@($man.permissions | ForEach-Object{ [string]$_ } | Where-Object{ $_ -match '^[a-z]{2,12}$' } | Select-Object -First 8) }
      } finally { $z.Dispose() }
    }catch{ $e.error=$_.Exception.Message }
    $out+=,$e
  }
  return @{ok=$true;dir=$dir;plugins=@($out)}
}

# ---------- System bridge (127.0.0.1 only, needs token, only the launcher page) ----------
function Send($c,[int]$code,$obj){
  $r=$c.Response; $r.StatusCode=$code
  $r.Headers.Add('Access-Control-Allow-Origin','*')
  $r.Headers.Add('Access-Control-Allow-Headers','X-Valy-Token, Content-Type')
  $r.Headers.Add('Access-Control-Allow-Methods','POST, OPTIONS')
  $r.Headers.Add('Access-Control-Allow-Private-Network','true')
  if($code -eq 204){ $r.Close(); return }
  $bytes=[Text.Encoding]::UTF8.GetBytes(($obj|ConvertTo-Json -Compress -Depth 6))
  $r.ContentType='application/json; charset=utf-8'
  $r.ContentLength64=$bytes.Length
  $r.OutputStream.Write($bytes,0,$bytes.Length)
  $r.OutputStream.Close()
}
function Handle-Request($c,[string]$token){
  $rq=$c.Request
  if($rq.HttpMethod -eq 'OPTIONS'){ Send $c 204 $null; return }
  $origin=$rq.Headers['Origin']
  if($origin -and $origin -ne 'null' -and $origin -notlike 'file:*'){ Send $c 403 @{ok=$false;error='origin'}; return }
  if($rq.Headers['X-Valy-Token'] -ne $token){ Send $c 401 @{ok=$false;error='token'}; return }
  $body=''
  if($rq.HasEntityBody){ $sr=New-Object IO.StreamReader($rq.InputStream,[Text.Encoding]::UTF8); $body=$sr.ReadToEnd(); $sr.Close() }
  $req=@{}
  if($body){ try{ Add-Type -AssemblyName System.Web.Extensions; $js=New-Object System.Web.Script.Serialization.JavaScriptSerializer; $js.MaxJsonLength=[int]::MaxValue; $req=$js.DeserializeObject($body) }catch{ $req=@{} } }
  function Q([string]$k){ if($req -and $req.ContainsKey($k) -and $null -ne $req[$k]){ return [string]$req[$k] } else { return '' } }
  switch($rq.Url.AbsolutePath){
    '/ping'   { $fl=Join-Path $Data 'clear-local.flag'; $cl=Test-Path -LiteralPath $fl; if($cl){ Remove-Item -LiteralPath $fl -Force -ErrorAction SilentlyContinue }; Send $c 200 @{ok=$true;name='Valy Bridge';user=$env:USERNAME;clear=$cl} }
    '/sysinfo'{ $o=@{ok=$true}; try{ $o.ram=[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1) }catch{}; try{ $cp=Get-CimInstance Win32_Processor|Select-Object -First 1; $o.cpu=([string]$cp.Name).Trim(); $o.cores=[int]$cp.NumberOfCores; $o.threads=[int]$cp.NumberOfLogicalProcessors }catch{}; try{ $o.gpu=@(Get-CimInstance Win32_VideoController|ForEach-Object{ [string]$_.Name }) }catch{}; try{ $os=Get-CimInstance Win32_OperatingSystem; $o.os=([string]$os.Caption).Trim()+' ('+$os.Version+')' }catch{}; Send $c 200 $o }
    '/steam'  { $o=@{ok=$true;games=@()}; try{ $sp=[string](Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction Stop).SteamPath; $libs=@($sp); $vf=Join-Path $sp 'steamapps\libraryfolders.vdf'; if(Test-Path -LiteralPath $vf){ foreach($m in [regex]::Matches((Get-Content -LiteralPath $vf -Raw),'"path"\s+"([^"]+)"')){ $libs+=($m.Groups[1].Value -replace '\\\\','\') } }; $g=@(); foreach($l in ($libs|Select-Object -Unique)){ $d=Join-Path $l 'steamapps'; if(-not (Test-Path -LiteralPath $d)){ continue }; foreach($f in Get-ChildItem -LiteralPath $d -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue){ try{ $t=Get-Content -LiteralPath $f.FullName -Raw; $id=[regex]::Match($t,'"appid"\s+"(\d+)"').Groups[1].Value; $nm=[regex]::Match($t,'"name"\s+"([^"]*)"').Groups[1].Value; if($id -and $nm -and $nm -notlike 'Steamworks*' -and $id -ne '228980'){ $g+=@{id=$id;name=$nm} } }catch{} } }; $o.games=@($g|Sort-Object { $_.name }) }catch{ $o.ok=$true; $o.steam=$false }; Send $c 200 $o }
    '/launch' { Open-Valy (Q 'mode') (Q 'path'); Send $c 200 @{ok=$true} }
    '/pick'   { $path=Pick-Path (Q 'kind'); Send $c 200 @{ok=$true;path=$path} }
    '/kill'   { $n=0; try{ $kp=[IO.Path]::GetFullPath((Q 'path')); Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { $_.ExecutablePath -and ($_.ExecutablePath -ieq $kp) -and ($_.ProcessId -ne $PID) } | ForEach-Object { $n++; & taskkill.exe /PID $_.ProcessId /T /F 2>$null | Out-Null } }catch{}; Send $c 200 @{ok=$true;killed=$n} }
    '/reveal' { Reveal (Q 'path'); Send $c 200 @{ok=$true} }
    '/license'{ $j=Get-Premium; Send $c 200 @{ok=$true;premium=[bool]$j;startup=(Get-Startup)} }
    '/plugins'{ Send $c 200 (Get-Plugins) }
    '/pluginsdir'{ $d=Join-Path $Root 'plugins'; $null=New-Item -ItemType Directory -Force -Path $d; Start-Process -FilePath 'explorer.exe' -ArgumentList ('"'+$d+'"'); Send $c 200 @{ok=$true} }
    '/premium'{ $pk=Get-Premium; if($pk){ Send $c 200 @{ok=$true;premium=$true;js=$pk.js;name=[string]$pk.lic.name} } else { Send $c 200 @{ok=$true;premium=$false} } }
    '/seticon'{
      $pk=Get-Premium
      if(-not $pk){ Send $c 403 @{ok=$false;error='premium'} }
      else{
        try{
          $bytes=[Convert]::FromBase64String((Q 'ico'))
          if($bytes.Length -lt 100 -or $bytes.Length -gt 2000000 -or $bytes[0] -ne 0 -or $bytes[1] -ne 0 -or $bytes[2] -ne 1 -or $bytes[3] -ne 0){ throw 'bad icon file' }
          Apply-AppIcon $bytes; Send $c 200 @{ok=$true}
        }catch{ Send $c 400 @{ok=$false;error=$_.Exception.Message} }
      }
    }
    '/desktop'{ try{ Set-DesktopShortcut ((Q 'on') -eq '1' -or (Q 'on') -eq 'true'); Send $c 200 @{ok=$true} }catch{ Send $c 400 @{ok=$false;error=$_.Exception.Message} } }
    '/startup'{ Set-Startup ((Q 'on') -eq '1' -or (Q 'on') -eq 'true'); Send $c 200 @{ok=$true;startup=(Get-Startup)} }
    '/verify' { Send $c 200 @{ok=$true;files=@(Check-Files)} }
    '/repair' { $r=Repair-Files; Send $c 200 @{ok=$true;files=@($r.files);failed=$r.failed} }
    '/exit'   { Send $c 200 @{ok=$true}; try{ Close-Valy }catch{}; $script:Quit=$true }
    '/temp'   {
      $dir=Join-Path $env:TEMP 'ValyLauncher'; $null=New-Item -ItemType Directory -Force -Path $dir
      $n=((Q 'name') -replace '[^\w\-\. ]','_'); if(-not $n){ $n='page' }
      $f=Join-Path $dir ($n+'-'+[guid]::NewGuid().ToString('N').Substring(0,6)+'.html')
      [IO.File]::WriteAllText($f,(Q 'content'),(New-Object Text.UTF8Encoding($true)))
      Send $c 200 @{ok=$true;path=$f}
    }
    default   { Send $c 404 @{ok=$false} }
  }
}
function Close-Valy{
  if(-not ('V.W' -as [type])){ Add-Type -Namespace V -Name W -MemberDefinition '[DllImport("user32.dll")] public static extern bool EnumWindows(EP p, IntPtr l); public delegate bool EP(IntPtr h, IntPtr l); [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, System.Text.StringBuilder s, int n); [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h); [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint m, IntPtr w, IntPtr l); public static void CloseByTitle(string pre){ EnumWindows(delegate(IntPtr h, IntPtr l){ if(IsWindowVisible(h)){ System.Text.StringBuilder sb=new System.Text.StringBuilder(256); GetWindowText(h,sb,256); if(sb.ToString().StartsWith(pre)) PostMessage(h,0x10,IntPtr.Zero,IntPtr.Zero); } return true; }, IntPtr.Zero); }' }
  [V.W]::CloseByTitle('Valy Launcher')
}
function Show-TrayMenu{
  param([string]$Title)
  Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
  if($script:TM -and -not $script:TM.IsDisposed){ try{ $script:TM.Close() }catch{} }
  $W=244; $H=80
  $f=New-Object System.Windows.Forms.Form
  $f.FormBorderStyle='None'; $f.ShowInTaskbar=$false; $f.TopMost=$true; $f.StartPosition='Manual'
  $f.Size=New-Object System.Drawing.Size($W,$H); $f.BackColor=[System.Drawing.Color]::FromArgb(22,20,58); $f.Opacity=1
  $pos=[System.Windows.Forms.Cursor]::Position
  $wa=[System.Windows.Forms.Screen]::FromPoint($pos).WorkingArea
  $x=[Math]::Max($wa.Left+8,[Math]::Min($pos.X-[int]($W/2),$wa.Right-$W-8))
  $y=[Math]::Max($wa.Top+8,[Math]::Min($pos.Y-$H-10,$wa.Bottom-$H-8))
  $f.Location=New-Object System.Drawing.Point($x,$y)
  $script:TMTop=$y; $script:TMStep=99
  $mk={ param($r) $d=2*$r; $g=New-Object System.Drawing.Drawing2D.GraphicsPath
    $g.AddArc(0,0,$d,$d,180,90); $g.AddArc($W-$d-1,0,$d,$d,270,90); $g.AddArc($W-$d-1,$H-$d-1,$d,$d,0,90); $g.AddArc(0,$H-$d-1,$d,$d,90,90); $g.CloseFigure(); return $g }
  $f.Region=New-Object System.Drawing.Region (& $mk 14)
  $f.add_Paint({ param($s,$e)
    $gx=$e.Graphics; $gx.SmoothingMode='AntiAlias'
    $rc=New-Object System.Drawing.Rectangle(0,0,$s.Width,$s.Height)
    $br=New-Object System.Drawing.Drawing2D.LinearGradientBrush($rc,[System.Drawing.Color]::FromArgb(40,34,104),[System.Drawing.Color]::FromArgb(16,16,46),55)
    $gx.FillRectangle($br,$rc); $br.Dispose()
    $pn=New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190,150,120,255),2)
    $r=14; $d=2*$r; $gp=New-Object System.Drawing.Drawing2D.GraphicsPath; $w2=$s.Width-2; $h2=$s.Height-2
    $gp.AddArc(1,1,$d,$d,180,90); $gp.AddArc($w2-$d,1,$d,$d,270,90); $gp.AddArc($w2-$d,$h2-$d,$d,$d,0,90); $gp.AddArc(1,$h2-$d,$d,$d,90,90); $gp.CloseFigure()
    $gx.DrawPath($pn,$gp); $gp.Dispose(); $pn.Dispose()
  })
  $hov=[System.Drawing.Color]::FromArgb(90,150,120,255)
  $items=@(@(('Open '+$Title),'open'),@('Exit','exit'))
  for($i=0;$i -lt 2;$i++){
    $l=New-Object System.Windows.Forms.Label
    $l.Text=''; $l.AccessibleName=[string]$items[$i][0]; $l.Tag=[string]$items[$i][1]; $l.AutoSize=$false
    $l.Size=New-Object System.Drawing.Size(($W-24),30); $l.Location=New-Object System.Drawing.Point(12,(10+$i*30))
    $l.Font=New-Object System.Drawing.Font('Segoe UI Semibold',9.5); $l.ForeColor=[System.Drawing.Color]::White
    $l.BackColor=[System.Drawing.Color]::Transparent; $l.TextAlign='MiddleLeft'; $l.Padding=New-Object System.Windows.Forms.Padding(12,0,0,0); $l.Cursor='Hand'
    $l.add_MouseEnter({ param($s,$e) $s.Name='h'; $s.Invalidate() })
    $l.add_MouseLeave({ param($s,$e) $s.Name=''; $s.Invalidate() })
    $l.add_Paint({ param($s,$e)
      $g=$e.Graphics; $g.SmoothingMode='AntiAlias'; $g.TextRenderingHint='AntiAliasGridFit'; $w=$s.Width-1; $h=$s.Height-1; $d=14
      if($s.Name -eq 'h'){
        $gp=New-Object System.Drawing.Drawing2D.GraphicsPath
        $gp.AddArc(0,0,$d,$d,180,90); $gp.AddArc($w-$d,0,$d,$d,270,90); $gp.AddArc($w-$d,$h-$d,$d,$d,0,90); $gp.AddArc(0,$h-$d,$d,$d,90,90); $gp.CloseFigure()
        $b=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(110,150,120,255)); $g.FillPath($b,$gp); $b.Dispose(); $gp.Dispose()
      }
      $sf=New-Object System.Drawing.StringFormat; $sf.LineAlignment='Center'; $sf.Alignment='Near'; $sf.FormatFlags='NoWrap'
      $tb=New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
      $g.DrawString([string]$s.AccessibleName,$s.Font,$tb,(New-Object System.Drawing.RectangleF(12,0,($s.Width-12),$s.Height)),$sf)
      $tb.Dispose(); $sf.Dispose()
    })
    $l.add_Click({ param($s,$e) $a=[string]$s.Tag; try{ $script:TM.Close() }catch{}; if($a -eq 'open'){ try{ Start-Valy ([pscustomobject]@{port=$Port;token=$script:Tok}) }catch{ [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Valy Launcher') } } else { try{ Close-Valy }catch{}; $script:Quit=$true } })
    $f.Controls.Add($l)
  }
  $tm=New-Object System.Windows.Forms.Timer; $tm.Interval=15
  $tm.add_Tick({
    $fm=$script:TM; if(-not $fm -or $fm.IsDisposed){ return }
    if(([System.Windows.Forms.Control]::MouseButtons -ne 'None') -and (-not $fm.Bounds.Contains([System.Windows.Forms.Cursor]::Position))){ try{ $fm.Close() }catch{} }
  })
  $f.add_Deactivate({ param($s,$e) if($script:TMStep -ge 12){ try{ $s.Close() }catch{} } })
  $f.add_FormClosed({ param($s,$e) try{ $script:TMTimer.Stop(); $script:TMTimer.Dispose() }catch{}; try{ $s.Dispose() }catch{} })
  $script:TM=$f; $script:TMTimer=$tm
  $f.Show(); [void]$f.Activate(); $tm.Start()
}
function Serve-Bridge{
  Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing
  $mx=New-Object Threading.Mutex($false,'Local\ValyLauncherBridge'); if(-not $mx.WaitOne(0)){ return }
  $token=[guid]::NewGuid().ToString('N'); $script:Tok=$token
  $l=New-Object System.Net.HttpListener
  $l.Prefixes.Add("http://127.0.0.1:$Port/")
  $l.Start()
  ([pscustomobject]@{port=$Port;token=$token;pid=$PID}|ConvertTo-Json)|Set-Content -LiteralPath $BridgeFile -Encoding ASCII
  $prem=[bool](Get-Premium); $title=$(if($prem){'Valy Launcher Premium'}else{'Valy Launcher'})
  $ni=New-Object System.Windows.Forms.NotifyIcon
  $ip=Join-Path $Icons 'valy-icon.ico'; if($prem){ if(Test-Path -LiteralPath (Join-Path $Data 'app-icon.ico')){ $ip=Join-Path $Data 'app-icon.ico' } elseif(Test-Path -LiteralPath (Join-Path $Icons 'valy-icon-premium.ico')){ $ip=Join-Path $Icons 'valy-icon-premium.ico' } }; try{ $ni.Icon=New-Object System.Drawing.Icon $ip }catch{ $ni.Icon=New-Object System.Drawing.Icon (Join-Path $Icons 'valy-icon.ico') }; $script:Ni=$ni
  $ni.Text=$title; $ni.Visible=$true
  $ni.add_MouseClick({ param($s,$e) if($e.Button -eq 'Right'){ try{ Show-TrayMenu $title }catch{}; return }; if($e.Button -ne 'Left'){ return }; try{ Start-Valy ([pscustomobject]@{port=$Port;token=$script:Tok}) }catch{ [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Valy Launcher') } })
  try{
    $t=$l.GetContextAsync()
    while(-not $script:Quit){
      [System.Windows.Forms.Application]::DoEvents()
      if($t.Wait(120)){
        $c=$t.Result; $t=$l.GetContextAsync()
        try{ Handle-Request $c $token }catch{ try{ Send $c 500 @{ok=$false;error=$_.Exception.Message} }catch{} }
      }
    }
  } finally { $ni.Visible=$false; $ni.Dispose(); $l.Stop(); Remove-Item -LiteralPath $BridgeFile -ErrorAction SilentlyContinue }
}
function Test-Bridge($cfg){ try{ $r=Invoke-RestMethod -Uri "http://127.0.0.1:$($cfg.port)/ping" -Method Post -Headers @{'X-Valy-Token'=$cfg.token} -Body '{}' -TimeoutSec 2; return [bool]$r.ok }catch{ return $false } }
function Get-Bridge{ if(Test-Path -LiteralPath $BridgeFile){ try{ $c=Get-Content -LiteralPath $BridgeFile -Raw|ConvertFrom-Json; if(Test-Bridge $c){ return $c } }catch{} }; return $null }
function Ensure-Bridge{
  $b=Get-Bridge
  if(-not $b){
    Start-Process -FilePath (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File',('"'+$PSCommandPath+'"'),'-Serve')
    for($i=0;$i -lt 40 -and -not $b;$i++){ Start-Sleep -Milliseconds 250; $b=Get-Bridge }
  }
  return $b
}
function Start-Valy($b=$null){
  if(-not $b){ $b=Ensure-Bridge }
  $url=([System.Uri](Join-Path $Sys 'valy-launcher.html')).AbsoluteUri
  if($b){ $url+="#vb=$($b.port).$($b.token)" }
  $pref='chrome'; $cfgFile=Join-Path $Sys 'config.json'
  if(Test-Path -LiteralPath $cfgFile){ try{ $cf=Get-Content -LiteralPath $cfgFile -Raw|ConvertFrom-Json; if($cf.browser){ $pref=[string]$cf.browser } }catch{} }
  if($pref -eq 'edge'){ $e=Get-Edge; if(-not $e){$e=Get-Chrome} } else { $e=Get-Chrome; if(-not $e){$e=Get-Edge} }
  if(-not $e){ throw 'Chrome or Edge was not found.' }
  Start-Process -FilePath $e -ArgumentList @("--app=$url",$G,'--window-size=1320,840')
}

try{
  if($Serve){ Serve-Bridge }
  elseif($Arg -eq 'tray'){ $null=Ensure-Bridge }
  elseif($Arg -eq 'machineid'){ Add-Type -AssemblyName System.Windows.Forms; $id=Get-MachineId; [System.Windows.Forms.Clipboard]::SetText($id); [void][System.Windows.Forms.MessageBox]::Show("Your Machine ID (copied):`n`n$id",'Valy Launcher') }
  elseif($Arg){ Handle-Proto $Arg }
  else{ Start-Valy }
}catch{
  if(-not $Serve){ Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.MessageBox]::Show($_.Exception.Message,'Valy Launcher') }
}
