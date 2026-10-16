using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Reflection;
using System.Text;
using System.Windows.Forms;
using Microsoft.Win32;
[assembly: System.Reflection.AssemblyTitle("Valy Launcher Setup")]
[assembly: System.Reflection.AssemblyProduct("Valy Launcher")]
[assembly: System.Reflection.AssemblyCompany("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyCopyright("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyVersion("3.2.2.0")]
[assembly: System.Reflection.AssemblyFileVersion("3.2.2.0")]

// Valy Launcher Setup (v2.8)
//  * ValyLauncherSetup.exe (colored icon)  = the installer wizard only: Welcome -> Folder -> Options -> Install -> Finish.
//  * After a successful install ONE colorless file is saved in the install folder: Valy-Uninstall.exe.
//    It is this same program; because its name contains "uninstall" it opens the Uninstall page with a few questions
//    and then removes the files that Valy created in the folder it was installed to (taken from the registry, or from its own folder).
//  * Update / Premium / .valyv / Repair / Plugin manager / Scan all live in OperatorSettings.exe now.
// C# 5 only (the .NET Framework compiler that ships with Windows).
namespace ValySetup
{
    static class Program
    {
        [STAThread]
        static void Main(string[] args)
        {
            Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
            Application.ThreadException += delegate { };   // a stray error must never close the window
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            bool un = false;
            try { un = Path.GetFileNameWithoutExtension(Application.ExecutablePath).ToLowerInvariant().Contains("uninstall"); } catch { }
            foreach (string a in args) if (a.ToLowerInvariant() == "/uninstall") un = true;
            AppDomain.CurrentDomain.UnhandledException += delegate (object s, UnhandledExceptionEventArgs e)
            {
                try
                {
                    string m = e.ExceptionObject == null ? "unknown error" : e.ExceptionObject.ToString();
                    try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "ValySetup-error.log"), m); } catch { }
                    MessageBox.Show("Valy Setup hit an error:\r\n\r\n" + m, "Valy Launcher Setup");
                }
                catch { }
            };
            try { Application.Run(new Wizard(un)); }
            catch (Exception ex)
            {
                try { File.WriteAllText(Path.Combine(Path.GetTempPath(), "ValySetup-error.log"), ex.ToString()); } catch { }
                MessageBox.Show("Valy Setup could not start:\r\n\r\n" + ex.Message, "Valy Launcher Setup");
            }
        }
    }

    // A modern flat button: rounded corners, gradient, soft hover animation.
    class FancyButton : Control
    {
        public Color A = Color.FromArgb(120, 90, 255), B = Color.FromArgb(0, 200, 255);
        public bool Ghost;
        float t; bool hover, down;
        System.Windows.Forms.Timer anim;

        public FancyButton(string text, int x, int y, int w, int h)
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable | ControlStyles.StandardClick, true);
            BackColor = Color.Transparent; ForeColor = Color.White; Cursor = Cursors.Hand; TabStop = true;
            Font = new Font("Segoe UI Semibold", 10f);
            Text = text; SetBounds(x, y, w, h);
            anim = new System.Windows.Forms.Timer(); anim.Interval = 16;
            anim.Tick += delegate
            {
                float goal = hover ? 1f : 0f;
                t += (goal - t) * 0.28f;
                if (Math.Abs(goal - t) < 0.02f) { t = goal; anim.Stop(); }
                Invalidate();
            };
        }
        protected override void Dispose(bool disposing) { if (disposing && anim != null) anim.Dispose(); base.Dispose(disposing); }
        protected override void OnMouseEnter(EventArgs e) { hover = true; anim.Start(); base.OnMouseEnter(e); }
        protected override void OnMouseLeave(EventArgs e) { hover = false; down = false; anim.Start(); base.OnMouseLeave(e); }
        protected override void OnMouseDown(MouseEventArgs e) { if (e.Button == MouseButtons.Left) { down = true; Focus(); Invalidate(); } base.OnMouseDown(e); }
        protected override void OnMouseUp(MouseEventArgs e) { down = false; Invalidate(); base.OnMouseUp(e); }
        protected override void OnEnabledChanged(EventArgs e) { Invalidate(); base.OnEnabledChanged(e); }
        protected override void OnTextChanged(EventArgs e) { Invalidate(); base.OnTextChanged(e); }
        protected override bool IsInputKey(Keys k) { return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k); }
        protected override void OnKeyUp(KeyEventArgs e) { if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) OnClick(EventArgs.Empty); base.OnKeyUp(e); }

        public static Color Mix(Color a, Color b, float k)
        {
            return Color.FromArgb((int)(a.R + (b.R - a.R) * k), (int)(a.G + (b.G - a.G) * k), (int)(a.B + (b.B - a.B) * k));
        }
        public static GraphicsPath Round(Rectangle r, int rad)
        {
            int d = rad * 2; GraphicsPath p = new GraphicsPath();
            p.AddArc(r.X, r.Y, d, d, 180, 90); p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
            p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90); p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
            p.CloseFigure(); return p;
        }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            if (Width < 6 || Height < 6) return;
            Rectangle r = new Rectangle(1, 1, Width - 3, Height - 3);
            using (GraphicsPath gp = Round(r, 11))
            {
                if (!Enabled)
                {
                    using (SolidBrush b0 = new SolidBrush(Color.FromArgb(70, 120, 130, 160))) g.FillPath(b0, gp);
                }
                else if (Ghost)
                {
                    using (SolidBrush b1 = new SolidBrush(Color.FromArgb((int)(34 + 56 * t), A))) g.FillPath(b1, gp);
                    using (Pen p1 = new Pen(Color.FromArgb((int)(120 + 120 * t), A), 1.4f)) g.DrawPath(p1, gp);
                }
                else
                {
                    Color c1 = Mix(A, Color.White, 0.2f * t), c2 = Mix(B, Color.White, 0.2f * t);
                    if (down) { c1 = Mix(c1, Color.Black, 0.2f); c2 = Mix(c2, Color.Black, 0.2f); }
                    using (LinearGradientBrush lb = new LinearGradientBrush(r, c1, c2, 0f)) g.FillPath(lb, gp);
                    using (Pen p2 = new Pen(Color.FromArgb((int)(30 + 140 * t), Color.White), 1.2f)) g.DrawPath(p2, gp);
                }
            }
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Center; sf.LineAlignment = StringAlignment.Center; sf.Trimming = StringTrimming.EllipsisCharacter; sf.FormatFlags = StringFormatFlags.NoWrap;
            using (SolidBrush tb = new SolidBrush(Enabled ? ForeColor : Color.FromArgb(150, 160, 180)))
                g.DrawString(Text, Font, tb, new RectangleF(4, down ? 1 : 0, Width - 8, Height), sf);
        }
    }

    class Wizard : Form
    {
        string tmp, payloadApp, installedDir, uDir;
        Panel[] pages = new Panel[6];
        int cur = 0;
        FancyButton back, next, cancel, launchBtn;
        TextBox dirBox;
        CheckBox cDesk, cMenu, cStart, cRun, qData, qPlug, qLic;
        bool fin_ok;
        Panel barPanel; int barVal; Label stepLbl, finLbl, finBody, uLoc; string graySaved;
        Image logo;
        bool busy, didInstall, didUninstall, uninstallOnly, allowClose;

        static readonly Color C1 = Color.FromArgb(120, 90, 255), C2 = Color.FromArgb(0, 200, 255), C3 = Color.FromArgb(60, 230, 160);
        static readonly Color BgA = Color.FromArgb(10, 18, 48), BgB = Color.FromArgb(18, 40, 92);
        static readonly Color Soft = Color.FromArgb(210, 225, 255);

        public Wizard(bool uninstall)
        {
            uninstallOnly = uninstall;
            Text = uninstallOnly ? "Valy Launcher Uninstall" : "Valy Launcher Setup";
            ClientSize = new Size(760, 500);
            FormBorderStyle = FormBorderStyle.FixedSingle; MaximizeBox = false;
            StartPosition = FormStartPosition.CenterScreen;
            DoubleBuffered = true; Font = new Font("Segoe UI", 10f);
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            Extract();
            try { logo = Image.FromFile(Path.Combine(Path.Combine(payloadApp, "icons"), "valy-icon-256.png")); } catch { }
            installedDir = GetInstalled();
            uDir = ResolveUninstallDir();

            for (int i = 0; i < pages.Length; i++)
            {
                pages[i] = new Panel { Left = 230, Top = 40, Width = 500, Height = 380, BackColor = Color.Transparent, Visible = false };
                Controls.Add(pages[i]);
            }
            BuildWelcome(); BuildFolder(); BuildOptions(); BuildProgress(); BuildFinish(); BuildUninstall();

            back = new FancyButton("Back", 372, 440, 110, 40); back.Ghost = true;
            next = new FancyButton("Next", 494, 440, 120, 40);
            cancel = new FancyButton("Cancel", 626, 440, 104, 40); cancel.Ghost = true; cancel.A = Color.FromArgb(150, 170, 220);
            back.Click += delegate { Go(cur - 1); };
            next.Click += OnNext; cancel.Click += delegate { if (!busy) { allowClose = true; Close(); } };
            Controls.AddRange(new Control[] { back, next, cancel });
            Go(uninstallOnly ? 5 : 0);
            FormClosing += delegate (object s, FormClosingEventArgs e)
            {
                // stay open while working, and ignore any stray programmatic Close(): only Finish / Launch / Cancel / the X button close the window
                if (busy) e.Cancel = true;
                else if (!allowClose && e.CloseReason == CloseReason.None) e.Cancel = true;
            };
            FormClosed += delegate
            {
                try { if (uninstallOnly && didUninstall) SelfDelete(Application.ExecutablePath, uDir); else MoveSetupToApp(); } catch { }
                try { if (tmp != null && Directory.Exists(tmp)) Directory.Delete(tmp, true); } catch { }
            };
        }

        Label MkLbl(string t, int x, int y, int w, int h, float size, bool bold, Color c)
        {
            return new Label { Text = t, Left = x, Top = y, Width = w, Height = h, ForeColor = c, BackColor = Color.Transparent, Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular) };
        }

        void Extract()
        {
            tmp = Path.Combine(Path.GetTempPath(), "ValySetup_" + Guid.NewGuid().ToString("N").Substring(0, 8));
            Directory.CreateDirectory(tmp);
            string zip = Path.Combine(tmp, "p.zip");
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("payload"))
            using (FileStream f = File.Create(zip)) { s.CopyTo(f); }
            ZipFile.ExtractToDirectory(zip, tmp);
            File.Delete(zip);
            payloadApp = Path.Combine(tmp, "payload");   // payload root: exe files, icons\, system\
        }

        string GetInstalled()
        {
            try { using (RegistryKey k = Registry.CurrentUser.OpenSubKey(@"Software\ValyLauncher")) { if (k != null) { object v = k.GetValue("InstallDir"); if (v != null && Directory.Exists(v.ToString())) return v.ToString(); } } } catch { }
            return null;
        }

        // the folder the uninstaller works on: the registry entry, otherwise the folder this exe sits in (if it looks like a Valy install)
        string ResolveUninstallDir()
        {
            string d = GetInstalled(); if (d != null) return d;
            try
            {
                string me = Path.GetDirectoryName(Application.ExecutablePath);
                if (File.Exists(Path.Combine(Path.Combine(me, "system"), "valy-helper.ps1"))) return me;
            }
            catch { }
            return null;
        }

        // ---------- pages ----------
        void BuildWelcome()
        {
            Panel p = pages[0];
            p.Controls.Add(MkLbl(installedDir == null ? "Welcome to Valy Launcher" : "Valy Launcher is already installed", 0, 10, 500, 36, 17f, true, Color.White));
            p.Controls.Add(MkLbl(installedDir == null
                ? "This wizard installs Valy Launcher on your PC, adds a tray icon and (if you like) starts it with Windows.\r\n\r\nClick Next to choose where to install it."
                : "Installed in:\r\n" + installedDir + "\r\n\r\nClick Next to update / reinstall it in the same place.\r\n(Update, Repair, Premium and Plugins are also inside Operator Settings.)", 0, 56, 500, 150, 10.5f, false, Soft));
        }
        void BuildFolder()
        {
            Panel p = pages[1];
            p.Controls.Add(MkLbl("Where should it be installed?", 0, 10, 500, 34, 16f, true, Color.White));
            p.Controls.Add(MkLbl("Valy Launcher keeps its files in this folder. You can pick any folder you like.", 0, 55, 500, 40, 10.5f, false, Soft));
            dirBox = new TextBox { Left = 0, Top = 112, Width = 380, Height = 28, Font = new Font("Segoe UI", 10.5f), Text = installedDir ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Programs\ValyLauncher") };
            FancyButton br = new FancyButton("Browse...", 392, 108, 108, 36); br.Ghost = true;
            br.Click += delegate { using (FolderBrowserDialog d = new FolderBrowserDialog()) { if (d.ShowDialog() == DialogResult.OK) dirBox.Text = Path.Combine(d.SelectedPath, "ValyLauncher"); } };
            p.Controls.AddRange(new Control[] { dirBox, br });
        }
        void BuildOptions()
        {
            Panel p = pages[2];
            p.Controls.Add(MkLbl("Choose what to set up", 0, 10, 500, 34, 16f, true, Color.White));
            cDesk = Chk("Add a shortcut to the Desktop", 70, true, p);
            cMenu = Chk("Add to the Start menu", 110, true, p);
            cStart = Chk("Run in the tray when Windows starts", 150, true, p);
            cRun = Chk("Open Valy Launcher when setup finishes", 190, true, p);
        }
        CheckBox Chk(string t, int y, bool v, Panel p)
        {
            CheckBox c = new CheckBox { Text = t, Left = 4, Top = y, Width = 490, Height = 30, Checked = v, ForeColor = Color.White, BackColor = Color.Transparent, Font = new Font("Segoe UI", 10.5f), Cursor = Cursors.Hand };
            p.Controls.Add(c); return c;
        }
        void BuildProgress()
        {
            Panel p = pages[3];
            p.Controls.Add(MkLbl("Working...", 0, 10, 500, 34, 16f, true, Color.White));
            stepLbl = MkLbl("Starting", 0, 80, 500, 30, 11f, false, Soft);
            barPanel = new Panel { Left = 0, Top = 125, Width = 490, Height = 18, BackColor = Color.Transparent };
            barPanel.Paint += delegate (object o, PaintEventArgs pe)
            {
                Graphics g = pe.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias;
                Rectangle r = new Rectangle(0, 0, barPanel.Width - 1, barPanel.Height - 1);
                using (GraphicsPath gp = FancyButton.Round(r, 8)) using (SolidBrush b = new SolidBrush(Color.FromArgb(60, 255, 255, 255))) g.FillPath(b, gp);
                int w = (int)((r.Width) * Math.Max(0, Math.Min(100, barVal)) / 100.0);
                if (w > 10)
                {
                    Rectangle f = new Rectangle(0, 0, w, r.Height);
                    using (GraphicsPath gp = FancyButton.Round(f, 8)) using (LinearGradientBrush lb = new LinearGradientBrush(f, C1, C2, 0f)) g.FillPath(lb, gp);
                }
            };
            p.Controls.AddRange(new Control[] { stepLbl, barPanel });
        }
        void SetProgress(int v) { barVal = v; barPanel.Invalidate(); }
        void BuildFinish()
        {
            Panel p = pages[4];
            finLbl = MkLbl("All done", 0, 10, 500, 34, 17f, true, Color.White);
            p.Controls.Add(finLbl);
            finBody = MkLbl("Valy Launcher is ready. You can find it on your Desktop and in the tray area next to the clock.", 0, 60, 500, 200, 11f, false, Soft);
            p.Controls.Add(finBody);
            launchBtn = new FancyButton("Launch Valy", 0, 296, 180, 42); launchBtn.Visible = false;
            launchBtn.Click += delegate
            {
                string d = installedDir ?? GetInstalled() ?? dirBox.Text.Trim().TrimEnd('\\');
                try { Process.Start(new ProcessStartInfo(Path.Combine(d, "ValyLauncher.exe")) { WorkingDirectory = d, UseShellExecute = true }); } catch { }
                allowClose = true; Close();
            };
            p.Controls.Add(launchBtn);
        }
        void BuildUninstall()
        {
            Panel p = pages[5];
            p.Controls.Add(MkLbl("Uninstall Valy Launcher", 0, 6, 500, 36, 17f, true, Color.White));
            uLoc = MkLbl(uDir == null ? "Valy Launcher was not found on this PC." : "Installed in:\r\n" + uDir, 0, 48, 500, 44, 10f, false, Soft);
            p.Controls.Add(uLoc);
            p.Controls.Add(MkLbl("A few questions before the files are removed:", 0, 102, 500, 24, 10.5f, true, Color.FromArgb(200, 235, 255)));
            qData = Chk("Also delete my data (games, notes, songs, settings, themes)", 134, false, p);
            qPlug = Chk("Also delete my installed plugins", 174, false, p);
            qLic = Chk("Keep my Premium license file (a reinstall stays Premium)", 214, true, p);
            p.Controls.Add(MkLbl("Valy removes only the files it created in that folder, plus its shortcuts, tray start-up entry and the valy:// link. Your own files are never touched.", 0, 268, 500, 60, 9.5f, false, Color.FromArgb(170, 190, 225)));
        }

        // ---------- navigation ----------
        void Go(int i)
        {
            if (i < 0) i = 0;
            cur = i;
            for (int k = 0; k < pages.Length; k++) pages[k].Visible = (k == cur);
            back.Visible = (cur == 1 || cur == 2);
            next.Visible = (cur != 3);
            next.Text = cur == 2 ? "Install" : (cur == 4 ? "Finish" : (cur == 5 ? "Uninstall" : "Next"));
            if (cur == 5) { next.A = Color.FromArgb(225, 70, 90); next.B = Color.FromArgb(255, 120, 80); next.Enabled = (uDir != null); }
            else { next.A = C1; next.B = C2; next.Enabled = true; }
            if (launchBtn != null) launchBtn.Visible = (cur == 4 && fin_ok);
            cancel.Visible = (cur != 4 && cur != 3);
            Invalidate();
        }
        void OnNext(object s, EventArgs e)
        {
            if (cur == 0) Go(1);
            else if (cur == 1)
            {
                if (dirBox.Text.Trim().Length < 4) { MessageBox.Show("Please choose a folder."); return; }
                Go(2);
            }
            else if (cur == 2) { Go(3); RunEngine("Install"); }
            else if (cur == 4)
            {
                if (didInstall && fin_ok && cRun != null && cRun.Checked)
                {
                    string d = installedDir ?? GetInstalled() ?? dirBox.Text.Trim().TrimEnd('\\');
                    try { Process.Start(new ProcessStartInfo(Path.Combine(d, "ValyLauncher.exe")) { WorkingDirectory = d, UseShellExecute = true }); } catch { }
                }
                allowClose = true; Close();
            }
            else if (cur == 5) { Go(3); RunEngine("Uninstall"); }
        }

        // ---------- engine ----------
        // The PowerShell engine writes its progress lines into a temp log file (no redirected pipes, so programs it starts such as the tray
        // cannot keep a pipe open) and the window follows that file with a UI timer. Everything runs on the UI thread: nothing here can
        // crash the setup from a background thread, and the Finish page is always shown.
        Process engine; string engineLog, engineAction, engineFail; System.Windows.Forms.Timer engineTimer; int engineSeen; DateTime engineStart;

        void RunEngine(string action)
        {
            busy = true; cancel.Enabled = false; SetProgress(0);
            engineAction = action; engineFail = null; engineSeen = 0; engineStart = DateTime.Now;
            try
            {
                foreach (string pn in new string[] { "ValyLauncher", "OperatorSettings", "ArtoulDefender" })
                    foreach (Process q in Process.GetProcessesByName(pn)) { try { if (q.Id == Process.GetCurrentProcess().Id) continue; q.Kill(); q.WaitForExit(1500); } catch { } }
            }
            catch { }
            string core = Path.Combine(Path.Combine(payloadApp, "system"), "Install-Core.ps1");
            engineLog = Path.Combine(tmp, "engine.log");
            try { File.WriteAllText(engineLog, ""); } catch { }
            StringBuilder a = new StringBuilder();
            a.Append("-NoProfile -ExecutionPolicy Bypass -File \"" + core + "\" -Action " + action);
            if (action == "Install") a.Append(" -Dir \"" + dirBox.Text.Trim().TrimEnd('\\') + "\" -Desktop " + (cDesk.Checked ? 1 : 0) + " -StartMenu " + (cMenu.Checked ? 1 : 0) + " -Startup " + (cStart.Checked ? 1 : 0) + " -RunAfter 0 -NoLaunch 1");
            if (action == "Uninstall") a.Append(" -Dir \"" + (uDir ?? "").TrimEnd('\\') + "\" -WipeData " + (qData.Checked ? 1 : 0) + " -WipePlugins " + (qPlug.Checked ? 1 : 0) + " -KeepLicense " + (qLic.Checked ? 1 : 0));
            // cmd.exe sends the output to the log file
            string cmdLine = "/c \"\"powershell.exe\" " + a.ToString() + " > \"" + engineLog + "\" 2>&1\"";
            ProcessStartInfo psi = new ProcessStartInfo("cmd.exe", cmdLine);
            psi.UseShellExecute = false; psi.CreateNoWindow = true; psi.WindowStyle = ProcessWindowStyle.Hidden;
            try { engine = Process.Start(psi); }
            catch (Exception ex) { engineFail = "Could not start PowerShell: " + ex.Message; EngineDone(); return; }
            engineTimer = new System.Windows.Forms.Timer(); engineTimer.Interval = 200;
            engineTimer.Tick += delegate { try { EngineTick(); } catch (Exception ex) { try { engineTimer.Stop(); engineFail = engineFail ?? ex.Message; EngineDone(); } catch { } } };
            engineTimer.Start();
        }

        void EngineTick()
        {
            bool exited = engine == null || engine.HasExited;
            string[] lines = new string[0];
            try
            {
                using (FileStream fs = new FileStream(engineLog, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (StreamReader sr = new StreamReader(fs, Encoding.GetEncoding(System.Globalization.CultureInfo.CurrentCulture.TextInfo.OEMCodePage)))
                    lines = sr.ReadToEnd().Replace("\r", "").Split('\n');
            }
            catch { }
            for (int k = engineSeen; k < lines.Length; k++)
            {
                string ln = lines[k].Trim('\uFEFF', ' ');
                if (ln.Length == 0) continue;
                string[] t = ln.Split('|');
                if (t[0] == "STEP" && t.Length >= 4)
                {
                    int i, n;
                    if (int.TryParse(t[1], out i) && int.TryParse(t[2], out n) && n > 0) { stepLbl.Text = t[3] + "..."; SetProgress(Math.Min(100, (int)(100.0 * i / n))); }
                }
                else if (t[0] == "FAIL") engineFail = ln.Substring(5);
            }
            engineSeen = lines.Length > 0 ? lines.Length - 1 : 0;   // the last line may still be incomplete
            if (exited)
            {
                // read the final lines once more, then finish
                if (engineSeen < lines.Length) { string last = lines[lines.Length - 1].Trim('\uFEFF', ' '); if (last.StartsWith("FAIL|")) engineFail = last.Substring(5); }
                engineTimer.Stop();
                EngineDone();
            }
            else if ((DateTime.Now - engineStart).TotalMinutes > 10) { engineTimer.Stop(); engineFail = "The installer took too long and was stopped."; try { engine.Kill(); } catch { } EngineDone(); }
        }

        void EngineDone()
        {
            string action = engineAction, fail = engineFail;
            try
            {
                busy = false; cancel.Enabled = true; SetProgress(100);
                if (fail == null && action == "Install")
                {
                    didInstall = true; try { graySaved = SaveUninstaller(); } catch { graySaved = null; }
                    string idir = dirBox.Text.Trim().TrimEnd('\\');
                    installedDir = idir;
                    // start the tray from here (detached), not from inside the install script
                    try { Process.Start(new ProcessStartInfo(Path.Combine(idir, "ValyLauncher.exe"), "tray") { WorkingDirectory = idir, UseShellExecute = true }); } catch { }
                    finBody.Text = "Valy Launcher was installed in:\r\n" + idir + "\r\n\r\nYou can find it on your Desktop and in the tray area next to the clock.\r\n\r\nPress Launch Valy to start it now, or Finish to close this window."
                        + (graySaved != null ? "\r\n\r\nValy-Uninstall.exe was saved in that folder - open it any time to remove Valy." : "");
                }
                if (fail == null && action == "Uninstall")
                {
                    didUninstall = true;
                    finBody.Text = "The files Valy created were removed from:\r\n" + uDir + "\r\n\r\n" + (qData.Checked ? "Your data was deleted too." : "Your data was kept.") + "\r\nThis window deletes itself when you close it.";
                }
                if (fail != null) { finLbl.Text = "Something went wrong"; finBody.Text = fail; }
                else finLbl.Text = action == "Uninstall" ? "Valy Launcher was removed" : "Installation complete";
                fin_ok = (fail == null && action != "Uninstall");
            }
            catch (Exception ex)
            {
                try { finLbl.Text = "Installation finished"; finBody.Text = "Valy Launcher was installed in:\r\n" + dirBox.Text.Trim().TrimEnd('\\') + "\r\n\r\n(" + ex.Message + ")"; fin_ok = (fail == null && action != "Uninstall"); } catch { }
            }
            finally { busy = false; try { Go(4); } catch { } }
        }

        // After a successful install the colorless (gray) copy of this program is saved INSIDE the install folder as the uninstaller.
        string SaveUninstaller()
        {
            string dir = dirBox.Text.Trim().TrimEnd('\\');
            string dest = Path.Combine(dir, "Valy-Uninstall.exe");
            // the old layout kept "ValyLauncherSetup.exe" inside the folder - remove it (unless it is the program running right now)
            try
            {
                string old = Path.Combine(dir, "ValyLauncherSetup.exe");
                if (File.Exists(old) && !string.Equals(old, Application.ExecutablePath, StringComparison.OrdinalIgnoreCase)) { File.SetAttributes(old, FileAttributes.Normal); File.Delete(old); }
            }
            catch { }
            if (string.Equals(Application.ExecutablePath, dest, StringComparison.OrdinalIgnoreCase)) return dest;   // already running from there
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("graysetup"))
            {
                if (s == null) return null;
                string t = dest + ".new";
                using (FileStream f = File.Create(t)) s.CopyTo(f);
                try { if (File.Exists(dest)) { File.SetAttributes(dest, FileAttributes.Normal); File.Delete(dest); } File.Move(t, dest); }
                catch { try { File.Delete(t); } catch { } return null; }
                try { File.SetAttributes(dest, FileAttributes.Normal); } catch { }
            }
            return dest;
        }

        // On close after an install: the downloaded (colored) setup removes itself - only the uninstaller stays in the install folder.
        void MoveSetupToApp()
        {
            if (!didInstall || graySaved == null) return;
            string orig = Application.ExecutablePath;
            if (string.Equals(orig, graySaved, StringComparison.OrdinalIgnoreCase)) return;
            RunHiddenCmd("/c ping 127.0.0.1 -n 3 >nul & for /l %i in (1,1,15) do @(if exist \"" + orig + "\" (del /f /q \"" + orig + "\" >nul 2>&1 & ping 127.0.0.1 -n 2 >nul)) & ie4uinit.exe -show >nul 2>&1");
        }

        // After an uninstall: this exe (it cannot delete itself while running) and the then-empty install folder are removed a moment later.
        static void SelfDelete(string exe, string dir)
        {
            string a = "/c ping 127.0.0.1 -n 3 >nul & for /l %i in (1,1,20) do @(if exist \"" + exe + "\" (del /f /q \"" + exe + "\" >nul 2>&1 & ping 127.0.0.1 -n 2 >nul))";
            if (!string.IsNullOrEmpty(dir)) a += " & rmdir \"" + dir.TrimEnd('\\') + "\" >nul 2>&1";   // rmdir without /s: only when the folder is empty
            RunHiddenCmd(a + " & ie4uinit.exe -show >nul 2>&1");
        }
        static void RunHiddenCmd(string args)
        {
            ProcessStartInfo i = new ProcessStartInfo("cmd.exe", args);
            i.CreateNoWindow = true; i.UseShellExecute = false; i.WindowStyle = ProcessWindowStyle.Hidden;
            Process.Start(i);
        }

        // ---------- painting ----------
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            using (LinearGradientBrush b = new LinearGradientBrush(ClientRectangle, BgA, BgB, 60f)) g.FillRectangle(b, ClientRectangle);
            Rectangle side = new Rectangle(0, 0, 210, ClientSize.Height);
            using (LinearGradientBrush b = new LinearGradientBrush(side, uninstallOnly ? Color.FromArgb(200, 60, 90) : C1, uninstallOnly ? Color.FromArgb(255, 130, 80) : C2, 90f)) g.FillRectangle(b, side);
            using (SolidBrush ov = new SolidBrush(Color.FromArgb(70, 5, 10, 40))) g.FillRectangle(ov, side);
            if (logo != null) g.DrawImage(logo, new Rectangle(35, 40, 140, 140));
            using (Font f = new Font("Segoe UI", 15f, FontStyle.Bold))
            using (LinearGradientBrush tb = new LinearGradientBrush(new Rectangle(0, 200, 210, 40), Color.White, Color.FromArgb(200, 255, 235), 0f))
            { StringFormat sf = new StringFormat { Alignment = StringAlignment.Center }; g.DrawString("Valy Launcher", f, tb, new RectangleF(0, 200, 210, 34), sf); }
            using (Font f = new Font("Segoe UI", 9f)) { StringFormat sf = new StringFormat { Alignment = StringAlignment.Center }; g.DrawString(uninstallOnly ? "Uninstall" : "by VisualC5 [LNTB017]", f, Brushes.White, new RectangleF(0, 236, 210, 20), sf); }
            if (!uninstallOnly)
            {
                string[] steps = { "Welcome", "Folder", "Options", "Install", "Finish" };
                for (int i = 0; i < steps.Length; i++)
                {
                    int y = 300 + i * 30; bool on = i == cur;
                    using (SolidBrush dot = new SolidBrush(on ? Color.White : Color.FromArgb(120, 255, 255, 255))) g.FillEllipse(dot, 30, y + 6, 10, 10);
                    using (Font f = new Font("Segoe UI", 10f, on ? FontStyle.Bold : FontStyle.Regular)) g.DrawString(steps[i], f, on ? Brushes.White : Brushes.Gainsboro, 50, y);
                }
            }
            base.OnPaint(e);
        }
    }
}
