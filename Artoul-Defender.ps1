# Artoul Defender - local safety check for the Valy Launcher package (read-only: it never deletes or edits anything)
param([switch]$Gui)  # -Gui: run inside ArtoulDefender.exe window (no console, no prompts, no emoji banner)
$ErrorActionPreference='SilentlyContinue'
try{ [Console]::OutputEncoding=[Text.Encoding]::UTF8; $OutputEncoding=[Text.Encoding]::UTF8 }catch{}
$Root=Split-Path -Parent $PSScriptRoot   # install folder (this script lives in ...\system)
$Self=$MyInvocation.MyCommand.Path
try{ $Host.UI.RawUI.WindowTitle='Artoul Defender' }catch{}

# --- enable 24-bit ANSI colors on the classic console ---
$script:ansi=$false
try{
  Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n); [DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h,out int m); [DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h,int m);' -Name 'K32' -Namespace 'Artoul' -ErrorAction Stop
  $hd=[Artoul.K32]::GetStdHandle(-11); $mode=0
  if([Artoul.K32]::GetConsoleMode($hd,[ref]$mode)){ $script:ansi=[Artoul.K32]::SetConsoleMode($hd,($mode -bor 4)) }
}catch{}
if($Gui){ $script:ansi=$false }
$ESC=[char]27
$CYAN=@(0,229,255); $MAG=@(255,0,170); $GREEN=@(57,255,20); $YEL=@(255,214,10); $RED=@(255,69,58); $VIO=@(168,85,247); $GRAY=@(140,150,170)

function Paint([string]$t,[int[]]$c){ if($script:ansi){ return "$ESC[38;2;$($c[0]);$($c[1]);$($c[2])m$t$ESC[0m" } else { return $t } }
function Grad([string]$t,[int[]]$a,[int[]]$b){
  if(-not $script:ansi -or $t.Length -eq 0){ return $t }
  $o=''; $n=[Math]::Max($t.Length-1,1)
  for($i=0;$i -lt $t.Length;$i++){
    $r=[int]($a[0]+($b[0]-$a[0])*$i/$n); $g=[int]($a[1]+($b[1]-$a[1])*$i/$n); $bl=[int]($a[2]+($b[2]-$a[2])*$i/$n)
    $o+="$ESC[38;2;$r;$g;${bl}m"+[string]$t[$i]
  }
  return $o+"$ESC[0m"
}
function Say([string]$t=''){ Write-Host $t }
function Good([string]$t){ Say ('   '+(Paint '✔' $GREEN)+' '+$t) }
function Warn([string]$t){ Say ('   '+(Paint '⚠' $YEL)+' '+(Paint $t $YEL)) }
function Bad([string]$t){ Say ('   '+(Paint '✖' $RED)+' '+(Paint $t $RED)) }
function Info([string]$t){ Say ('   '+(Paint '•' $GRAY)+' '+(Paint $t $GRAY)) }
function Step([int]$n,[string]$emoji,[string]$t){ Say ''; Say ('  '+$emoji+'  '+(Grad ('STEP '+$n+' · '+$t) $CYAN $MAG)); Start-Sleep -Milliseconds 200 }
function Bar([int]$i,[int]$n,[string]$label){
  $w=30; $f=[int]($w*$i/[Math]::Max($n,1))
  $b=(Grad (''.PadLeft($f,'█')) $CYAN $MAG)+(Paint (''.PadLeft($w-$f,'░')) $GRAY)
  Write-Host -NoNewline ("`r   "+$b+' '+(Paint ([string]$i+'/'+[string]$n) $GRAY)+' '+$label+'                    ')
}
function Rel($f){ return $f.FullName.Substring($Root.Length).TrimStart('\') }
# Valy's own program / Premium files: never reported as new, modified or risky (they are rebuilt on every update and Premium changes them).
$OwnNames=@('ValyLauncher.exe','OperatorSettings.exe','OperatorSettings.exe.old','ArtoulDefender.exe','Valy-Uninstall.exe','ValyLauncherSetup.exe','premium.valylic','app-icon.ico','manifest.sha256','package.sig','valy-pub.xml','valy-launcher.html','valy-premium.ps1','valy-helper.ps1','Install-Core.ps1','Artoul-Defender.ps1')
function Is-Own($f){ $n=$f.Name; if($OwnNames -contains $n){ return $true }; if($n -like 'valy-icon*' -or $n -like 'valy-op*' -or $n -like 'valy-defender*' -or $n -like '*premium*'){ if($f.FullName -like (Join-Path $Root 'icons\*') -or $f.FullName -like (Join-Path $Root 'data\*')){ return $true } }; return $false }

# ---------------- banner ----------------
if(-not $Gui){
Clear-Host
Say ''
Say ('   '+(Grad '╔══════════════════════════════════════════════════╗' $CYAN $MAG))
Say ('   '+(Grad '║                                                  ║' $CYAN $MAG))
Say ('   '+(Grad '║        A R T O U L   D E F E N D E R             ║' $CYAN $MAG))
Say ('   '+(Grad '║        Valy Launcher · safety check              ║' $CYAN $MAG))
Say ('   '+(Grad '║                                                  ║' $CYAN $MAG))
Say ('   '+(Grad '╚══════════════════════════════════════════════════╝' $CYAN $MAG))
Say ('        🛡️  🔍  🧬  🔐  🚀   '+(Paint ((Get-Date).ToString('yyyy-MM-dd HH:mm')) $GRAY))
Say ''
}
Info ('Folder: '+$Root)
Info 'Read-only scan: nothing is deleted or modified.'

$findHigh=0; $findMed=0

# ---------------- step 1: inventory ----------------
Step 1 '📦' 'Collecting files'
$files=@(Get-ChildItem -LiteralPath $Root -Recurse -File -Force | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notlike (Join-Path $Root 'data\*') -and $_.FullName -notlike (Join-Path $Root 'plugins\*') })
$size=($files | Measure-Object -Property Length -Sum).Sum
Good ('{0} files · {1:N1} MB' -f $files.Count,($size/1MB))

# ---------------- step 2: integrity ----------------
Step 2 '🔐' 'Integrity check (SHA-256)'
$manPath=Join-Path $PSScriptRoot 'manifest.sha256'
$man=@{}
if(Test-Path -LiteralPath $manPath){ foreach($ln in (Get-Content -LiteralPath $manPath)){ if($ln -match '^([0-9a-fA-F]{64}) \*(.+)$'){ $man[$Matches[2]]=$Matches[1].ToLower() } } }
if($man.Count -eq 0){
  Warn 'manifest.sha256 is missing - cannot verify file integrity.'; $findMed++
}else{
  $skipHash=@('manifest.sha256','config.json','ValyLauncherSetup.exe','Valy-Uninstall.exe','OperatorSettings.exe.old','data\operator-report.txt','data\clear-local.flag'); $i=0; $mod=0; $new=0; $okc=0
  foreach($f in $files){
    $i++; $r=Rel $f; Bar $i $files.Count $r
    if($skipHash -contains $r -or $f.Extension -eq '.lnk' -or (Is-Own $f)){ continue }
    if(-not $man.ContainsKey($r)){ $new++; Say ''; Warn ('New file not in the original package: '+$r); $findMed++; continue }
    $h=(Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower()
    if($h -ne $man[$r]){ $mod++; Say ''; Bad ('Modified since packaging: '+$r); $findHigh++ } else { $okc++ }
  }
  Say ''
  foreach($k in $man.Keys){ if(-not (Test-Path -LiteralPath (Join-Path $Root $k))){ Warn ('Missing file: '+$k); $findMed++ } }
  if($mod -eq 0){ Good ('{0} files match the original fingerprints' -f $okc) }
}

# ---------------- step 3: dangerous types / hidden executables ----------------
Step 3 '🚫' 'Executables and risky file types'
$riskExt=@('.exe','.dll','.scr','.com','.pif','.msi','.jar','.vbe','.jse','.wsf','.hta','.cpl','.sys','.msc','.reg','.apk')
$badFound=0
foreach($f in $files){
  $r=Rel $f
  if(Is-Own $f){ continue }
  $isPE=$false
  try{ $fs=[IO.File]::OpenRead($f.FullName); try{ $bb=New-Object byte[] 2; [void]$fs.Read($bb,0,2); $isPE=($bb[0] -eq 0x4D -and $bb[1] -eq 0x5A) } finally{ $fs.Close() } }catch{}
  if($isPE -and @('ValyLauncher.exe','ArtoulDefender.exe','OperatorSettings.exe') -contains $r -and $man.ContainsKey($r) -and ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower() -eq $man[$r])){ Good ('Own Valy program, fingerprint verified: '+$r); continue }
  if($isPE -and $r -eq 'OperatorSettings.exe'){ Info 'OperatorSettings.exe = the Valy Operator Settings program'; continue }
  if($isPE -and ($r -eq 'Valy-Uninstall.exe' -or $r -eq 'OperatorSettings.exe.old')){ Info ($r+' = Valy uninstaller / previous Operator Settings copy (not in the fingerprint list)'); continue }
  if($isPE -and $r -eq 'ValyLauncherSetup.exe'){ Info 'ValyLauncherSetup.exe = the Valy installer (not in the fingerprint list)'; continue }
  if($isPE){ Bad ('Windows executable inside the package: '+$r); $findHigh++; $badFound++ }
  elseif($riskExt -contains $f.Extension.ToLower()){ Bad ('Risky file type: '+$r); $findHigh++; $badFound++ }
}
if($badFound -eq 0){ Good 'No executables, DLLs or disguised programs found' }

# ---------------- step 4: script patterns ----------------
Step 4 '🧬' 'Suspicious code patterns'
$scriptExt=@('.ps1','.psm1','.vbs','.bat','.cmd'); $webExt=@('.html','.htm','.js')
$P=@(
 @{S='High';N='Runs downloaded/dynamic code (Invoke-Expression)';R='(?i)Invoke-Expression|\|\s*iex\b|;\s*iex\b|^\s*iex\s'},
 @{S='High';N='Downloads files from the internet';R='(?i)DownloadString|DownloadFile|DownloadData|Net\.WebClient|Start-BitsTransfer|bitsadmin|certutil(\.exe)?\s.*urlcache|Invoke-WebRequest|\biwr\b'},
 @{S='High';N='Encoded / obfuscated command';R='(?i)-EncodedCommand|\s-enc\s|FromBase64String[^\r\n]*(Invoke-Expression|\biex\b|Assembly\]::Load)'},
 @{S='High';N='Disables or weakens Windows Defender / firewall';R='(?i)Set-MpPreference|Add-MpPreference|DisableRealtimeMonitoring|DisableAntiSpyware|advfirewall\s+set.*off'},
 @{S='High';N='Persistence (scheduled task / autorun / service)';R='(?i)schtasks|ScheduledTask|CurrentVersion\\Run|New-Service|sc(\.exe)?\s+create'},
 @{S='High';N='Abuses system tools (mshta / regsvr32 / rundll32)';R='(?i)\bmshta\b|\bregsvr32\b|\brundll32\b|InstallUtil|wmic\s+process'},
 @{S='High';N='Destructive commands (shadow copies / disk wipe)';R='(?i)vssadmin\s+delete|cipher\s+/w|bcdedit|wbadmin\s+delete|format\s+[a-z]:'},
 @{S='High';N='Keylogging / screen capture / credential access';R='(?i)GetAsyncKeyState|SetWindowsHookEx|CopyFromScreen|Get-Credential|mimikatz|lsass|Login Data'},
 @{S='High';N='Raw network sockets / reverse shell';R='(?i)Net\.Sockets|TCPClient|\bncat\b|\bnc\.exe\b'},
 @{S='High';N='Crypto-miner strings';R='(?i)coinhive|cryptonight|stratum\+tcp|xmrig'},
 @{S='Med';N='Loads script from an external website';R='(?i)<script[^>]+src\s*=\s*["'']?https?://'},
 @{S='Med';N='Dynamic code execution (eval / new Function)';R='(?i)\beval\s*\(|new\s+Function\s*\(|document\.write\s*\(\s*unescape'}
)
$scanned=0; $hits=0; $i=0; $trusted=0
$ownScripts=@('system\Install-Core.ps1','system\valy-helper.ps1','system\valy-premium.ps1','system\Artoul-Defender.ps1')
foreach($f in $files){
  $ext=$f.Extension.ToLower(); $r=Rel $f
  $isS=$scriptExt -contains $ext; $isW=$webExt -contains $ext
  if(-not ($isS -or $isW)){ continue }
  $i++; Bar $i $files.Count $r
  if($f.FullName -eq $Self -or (Is-Own $f)){ $trusted++; continue }
  # Valy's own scripts (Install-Core, helper, ...) legitimately contain words like 'startup' / 'download' that the patterns look for.
  # If the file still matches its original fingerprint in manifest.sha256 it is trusted and is not pattern-scanned again.
  if($ownScripts -contains $r -and $man.ContainsKey($r) -and ((Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash.ToLower() -eq $man[$r])){ $trusted++; continue }
  $txt=[IO.File]::ReadAllText($f.FullName); $scanned++
  foreach($p in $P){
    $web=($p.N -like 'Loads script*' -or $p.N -like 'Dynamic code*')
    if($web -and -not $isW){ continue }
    if((-not $web) -and (-not $isS)){ continue }
    if([regex]::IsMatch($txt,$p.R,'Multiline')){
      $hits++; Say ''
      if($p.S -eq 'High'){ Bad ($p.N+' -> '+$r); $findHigh++ } else { Warn ($p.N+' -> '+$r); $findMed++ }
    }
  }
}
Say ''
if($trusted -gt 0){ Info ('{0} own Valy scripts verified by fingerprint (not pattern-scanned)' -f $trusted) }
if($hits -eq 0){ Good ('{0} code files checked - no suspicious patterns' -f $scanned) }
Info 'Artoul-Defender.ps1 itself is excluded (it contains the pattern list) and is verified by hash in step 2.'

# ---------------- step 5: network references ----------------
Step 5 '🌐' 'Websites the launcher page talks to'
$dom=@{}
foreach($f in $files){ if($webExt -contains $f.Extension.ToLower()){ foreach($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName),'https?://([a-zA-Z0-9.-]+)')){ $d=$m.Groups[1].Value.ToLower(); if($d -notin @('127.0.0.1','localhost','www.w3.org')){ $dom[$d]=1 } } } }
if($dom.Count -eq 0){ Good 'No external websites referenced' } else { foreach($d in ($dom.Keys | Sort-Object)){ Info ('references '+$d) } }

# ---------------- step 6: mark of the web ----------------
Step 6 '🔒' 'Downloaded-file lock (Mark of the Web)'
$blocked=@($files | Where-Object { Get-Item -LiteralPath $_.FullName -Stream Zone.Identifier -ErrorAction SilentlyContinue })
if($blocked.Count -eq 0){ Good 'No files are blocked by Windows' }
else{
  Warn ('{0} file(s) are still marked as downloaded (Windows may show SmartScreen warnings).' -f $blocked.Count); $findMed++
  if($Gui){ Say '@@ASK_UNBLOCK@@'; $ans=[Console]::In.ReadLine() } else { $ans=Read-Host '   Unblock them now? [Y/N]' }
  if($ans -match '^[Yy]'){ $blocked | ForEach-Object { Unblock-File -LiteralPath $_.FullName }; Good 'Unblocked.' }
}

# ---------------- step 7: Windows Defender engine ----------------
Step 7 '🛡️' 'Windows Defender engine scan'
$mp=Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
$plat=Get-ChildItem -LiteralPath (Join-Path $env:ProgramData 'Microsoft\Windows Defender\Platform') -Directory | Sort-Object Name -Descending | Select-Object -First 1
if($plat){ $c=Join-Path $plat.FullName 'MpCmdRun.exe'; if(Test-Path -LiteralPath $c){ $mp=$c } }
if(-not (Test-Path -LiteralPath $mp)){ Info 'Windows Defender engine not found (another antivirus may be active) - skipped.' }
else{
  $pr=Start-Process -FilePath $mp -ArgumentList @('-Scan','-ScanType','3','-File',('"'+$Root+'"'),'-DisableRemediation') -PassThru -WindowStyle Hidden
  $fr='⠋','⠙','⠹','⠸','⠼','⠴','⠦','⠧','⠇','⠏'; $k=0
  while($pr -and -not $pr.HasExited){ Write-Host -NoNewline ("`r   "+(Paint $fr[$k % $fr.Count] $CYAN)+' Defender is scanning...                 '); $k++; Start-Sleep -Milliseconds 120 }
  Say ''
  if($pr.ExitCode -eq 0){ Good 'Windows Defender: no threats found' }
  elseif($pr.ExitCode -eq 2){ Bad 'Windows Defender reported a threat! Open Windows Security > Protection history.'; $findHigh++ }
  else{ Info ('Windows Defender could not finish (code '+$pr.ExitCode+') - skipped.') }
}

# ---------------- step 8: plugins ----------------
Step 8 '🧩' 'Plugins (.valyp)'
$pd=Join-Path $Root 'plugins'
$pl=@(); if(Test-Path -LiteralPath $pd){ $pl=@(Get-ChildItem -LiteralPath $pd -Filter '*.valyp' -File) }
if($pl.Count -eq 0){ Good 'No plugins installed' }
else{
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $pp=@(
    @{N='talks to the internet';R='(?i)\bfetch\s*\(|XMLHttpRequest|WebSocket|sendBeacon|https?://(?!www\.w3\.org)'},
    @{N='uses the system bridge or its token';R='(?i)X-Valy-Token|\bbr\s*\(|127\.0\.0\.1'},
    @{N='runs dynamic code';R='(?i)\beval\s*\(|new\s+Function\s*\('},
    @{N='reads the browser storage directly';R='(?i)\blocalStorage\b|\bsessionStorage\b|\bindexedDB\b'}
  )
  foreach($f in $pl){
    $hit=@()
    try{
      $z=[IO.Compression.ZipFile]::OpenRead($f.FullName)
      try{
        foreach($en in $z.Entries){
          if($en.FullName -match '\.(js|json|css|html?)$' -and $en.Length -lt 3MB){
            $sr=New-Object IO.StreamReader($en.Open()); $tx=$sr.ReadToEnd(); $sr.Dispose()
            foreach($q in $pp){ if([regex]::IsMatch($tx,$q.R)){ $hit+=$q.N } }
          }
        }
      } finally { $z.Dispose() }
    }catch{ Warn ('Cannot read plugin file: '+$f.Name); $findMed++; continue }
    $hit=@($hit | Sort-Object -Unique)
    if($hit.Count -eq 0){ Good ($f.Name+' - no risky patterns') } else { Warn ($f.Name+' -> '+($hit -join ', ')); $findMed++ }
  }
  Info 'A plugin runs with the same power as the app. Only turn on plugins from people you trust.'
}

# ---------------- verdict ----------------
Say ''
Say ('  '+(Grad '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' $MAG $CYAN))
if($findHigh -gt 0){
  Say ('  ❌  '+(Paint 'DANGER - serious findings: ' $RED)+(Paint ([string]$findHigh) $RED)+(Paint ('   (warnings: '+$findMed+')') $YEL))
  Say (Paint '      Do not run this package. Download it again from the original source.' $RED)
}elseif($findMed -gt 0){
  Say ('  ⚠️  '+(Paint 'REVIEW - no threats, but warnings: ' $YEL)+(Paint ([string]$findMed) $YEL))
  Say (Paint '      Read the yellow lines above.' $YEL)
}else{
  Say ('  ✅  '+(Grad 'ALL CLEAR - the package is intact and nothing suspicious was found' $GREEN $CYAN)+'  🎉')
}
Say ('  '+(Grad '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━' $MAG $CYAN))
Say (Paint '  This is a local safety check; it does not replace a full antivirus.' $GRAY)
Say ''
if(-not $Gui){
  Say ('  '+(Paint 'Press ' $GRAY)+(Paint 'ENTER' $GREEN)+(Paint ' to close...' $GRAY))
  [void][Console]::ReadLine()
}
