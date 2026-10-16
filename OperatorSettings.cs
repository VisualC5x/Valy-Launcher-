using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.IO;
using System.IO.Compression;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;
[assembly: System.Reflection.AssemblyTitle("Operator Settings")]
[assembly: System.Reflection.AssemblyProduct("Valy Launcher")]
[assembly: System.Reflection.AssemblyCompany("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyCopyright("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyVersion("3.2.2.0")]
[assembly: System.Reflection.AssemblyFileVersion("3.2.2.0")]

// OperatorSettings.exe - the Operator Settings window (v2.8). NOT part of the setup; after install it sits next to ValyLauncher.exe.
// Everything that manages the installation lives here now:
//   Security scan (big round button), Fix / Repair, Unblock files, Last report,
//   Update app (opens a newer ValyLauncherSetup.exe), Update from .valyv, Update Premium,
//   Plugin manager, Open app folder, Clear all data, Uninstall (opens Valy-Uninstall.exe).
// Scan runs system\Artoul-Defender.ps1 -Gui hidden. Updates run system\Install-Core.ps1 with the matching -Action.
// Build:  csc /target:winexe /win32icon:valy-op.ico /r:System.Windows.Forms.dll /r:System.Drawing.dll /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll OperatorSettings.cs
// (C# 5 only - the .NET Framework compiler that ships with Windows)
namespace ValyOperatorSettings
{
    static class Program
    {
        [STAThread]
        static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new Win());
        }
    }

    // Modern flat button: rounded, gradient, animated hover.
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

    // Side-menu button: transparent until hovered, then a soft glow and a growing accent bar.
    class NavBtn : Control
    {
        public Color Accent = Color.FromArgb(0, 229, 255);
        float t; bool hover, down;
        System.Windows.Forms.Timer anim;

        public NavBtn(string text, int x, int y, int w, int h)
        {
            SetStyle(ControlStyles.UserPaint | ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.SupportsTransparentBackColor | ControlStyles.Selectable | ControlStyles.StandardClick, true);
            BackColor = Color.Transparent; Cursor = Cursors.Hand; TabStop = true;
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
        protected override bool IsInputKey(Keys k) { return k == Keys.Enter || k == Keys.Space || base.IsInputKey(k); }
        protected override void OnKeyUp(KeyEventArgs e) { if (e.KeyCode == Keys.Space || e.KeyCode == Keys.Enter) OnClick(EventArgs.Empty); base.OnKeyUp(e); }
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.TextRenderingHint = System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
            if (Width < 12 || Height < 12) return;
            Rectangle r = new Rectangle(0, 0, Width - 1, Height - 1);
            if (t > 0.01f)
                using (GraphicsPath gp = FancyButton.Round(r, 10))
                using (SolidBrush b = new SolidBrush(Color.FromArgb((int)(55 * t) + (down ? 25 : 0), Accent))) g.FillPath(b, gp);
            int bh = (int)(8 + 16 * t);
            Rectangle bar = new Rectangle(5, (Height - bh) / 2, 4, bh);
            using (GraphicsPath bp = FancyButton.Round(bar, 2))
            using (SolidBrush ab = new SolidBrush(FancyButton.Mix(Color.FromArgb(90, 100, 130), Accent, 0.35f + 0.65f * t))) g.FillPath(ab, bp);
            StringFormat sf = new StringFormat();
            sf.Alignment = StringAlignment.Near; sf.LineAlignment = StringAlignment.Center; sf.Trimming = StringTrimming.EllipsisCharacter; sf.FormatFlags = StringFormatFlags.NoWrap;
            using (SolidBrush tb = new SolidBrush(FancyButton.Mix(Color.FromArgb(200, 210, 230), Color.White, t)))
                g.DrawString(Text, Font, tb, new RectangleF(22, 0, Width - 26, Height), sf);
        }
    }

    class Win : Form
    {
        [DllImport("user32.dll")] static extern bool ReleaseCapture();
        [DllImport("user32.dll")] static extern IntPtr SendMessage(IntPtr h, int m, int w, int l);

        const int SW = 252;      // side menu width
        const int TB = 40;       // title bar height
        static readonly Color Bg = Color.FromArgb(12, 16, 34);
        static readonly Color Side = Color.FromArgb(17, 22, 46);
        static readonly Color Bar = Color.FromArgb(8, 11, 24);
        static readonly Color Cyan = Color.FromArgb(0, 229, 255);
        static readonly Color Mag = Color.FromArgb(255, 0, 170);
        static readonly Color Green = Color.FromArgb(57, 255, 20);
        static readonly Color Yel = Color.FromArgb(255, 214, 10);
        static readonly Color Red = Color.FromArgb(255, 69, 58);
        static readonly Color Gray = Color.FromArgb(140, 150, 170);
        static readonly Color Txt = Color.FromArgb(222, 230, 245);
        static readonly Color Violet = Color.FromArgb(150, 110, 255);

        string dir, sysDir;
        Image logo;
        RichTextBox log;
        Label status;
        Panel ring, side;
        CheckBox cUnblock, cKeep;
        System.Windows.Forms.Timer spin;
        float angle;
        bool running, hover, maxed, opBusy;
        Process proc;
        Font fReg, fBold;
        string lastReport = "";
        Rectangle rMin, rMax, rClose;

        public Win()
        {
            dir = AppDomain.CurrentDomain.BaseDirectory;
            sysDir = Path.Combine(dir, "system");
            try { string old = Path.Combine(dir, "OperatorSettings.exe.old"); if (File.Exists(old)) File.Delete(old); } catch { }   // left behind by an update that ran inside this window
            Text = "Operator Settings";
            FormBorderStyle = FormBorderStyle.None;
            ClientSize = new Size(980, 660);
            MinimumSize = new Size(880, 620);
            StartPosition = FormStartPosition.CenterScreen;
            BackColor = Bg;
            Font = new Font("Segoe UI", 10f);
            DoubleBuffered = true;
            try { Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath); } catch { }
            try { logo = Image.FromFile(Path.Combine(Path.Combine(dir, "icons"), "valy-op-512.png")); } catch { }

            side = new Panel(); side.BackColor = Side; side.Paint += SidePaint;
            Header("SECURITY", 98);
            AddNav("Fix / Repair", 120, Cyan, delegate { ManifestCheck(true); });
            AddNav("Unblock files", 157, Cyan, delegate { UnblockAll(); });
            AddNav("Last report", 194, Cyan, delegate { ShowReport(); });
            Header("UPDATES", 236);
            AddNav("Update app", 258, Violet, delegate { UpdateApp(); });
            AddNav("Update from .valyv file", 295, Violet, delegate { UpdateValyv(); });
            AddNav("Update Premium", 332, Yel, delegate { PremiumDialog(); });
            Header("TOOLS", 374);
            AddNav("Plugin manager", 396, Mag, delegate { PluginManager(); });
            AddNav("Open app folder", 433, Mag, delegate { try { Process.Start("explorer.exe", "\"" + dir + "\""); } catch { } });
            AddNav("Clear all data", 470, Mag, delegate { ClearAllData(); });
            AddNav("Uninstall Valy", 518, Red, delegate { UninstallValy(); });

            ring = new Panel();
            ring.Size = new Size(170, 170);
            ring.BackColor = Bg;
            ring.Cursor = Cursors.Hand;
            ring.Paint += RingPaint;
            ring.MouseEnter += delegate { hover = true; ring.Invalidate(); };
            ring.MouseLeave += delegate { hover = false; ring.Invalidate(); };
            ring.Click += delegate { StartScan(); };

            log = new RichTextBox();
            log.ReadOnly = true; log.BorderStyle = BorderStyle.None; log.BackColor = Color.FromArgb(8, 11, 24);
            log.ForeColor = Txt; log.Font = new Font("Consolas", 10f); log.DetectUrls = false; log.WordWrap = false;
            log.ScrollBars = RichTextBoxScrollBars.Both;
            log.Visible = false;
            fReg = log.Font; fBold = new Font(log.Font, FontStyle.Bold);

            status = new Label();
            status.ForeColor = Gray; status.BackColor = Color.Transparent; status.Text = "Press SCAN to check this installation";
            status.TextAlign = ContentAlignment.MiddleCenter;

            cUnblock = Chk("Offer to unblock files after a scan", true);
            cKeep = Chk("Keep the last report", true);

            Controls.AddRange(new Control[] { side, ring, log, status, cUnblock, cKeep });

            spin = new System.Windows.Forms.Timer();
            spin.Interval = 30;
            spin.Tick += delegate { angle = (angle + 9f) % 360f; ring.Invalidate(); };

            Layout += delegate { DoLayout(); };
            Resize += delegate { Invalidate(); };
            MouseDown += TitleDown;
            MouseDoubleClick += delegate(object s, MouseEventArgs e) { if (e.Y < TB && e.X < ClientSize.Width - 130) ToggleMax(); };
            MouseClick += TitleClick;
            FormClosing += delegate
            {
                try { if (proc != null && !proc.HasExited) proc.Kill(); } catch { }
            };
            DoLayout();
        }

        NavBtn AddNav(string text, int y, Color accent, EventHandler click)
        {
            NavBtn b = new NavBtn(text, 12, y, SW - 24, 36);
            b.Accent = accent; b.Click += click; side.Controls.Add(b); return b;
        }
        void Header(string text, int y)
        {
            Label l = new Label();
            l.Text = text; l.Left = 20; l.Top = y; l.Width = SW - 40; l.Height = 18;
            l.ForeColor = Color.FromArgb(105, 118, 150); l.BackColor = Color.Transparent; l.Font = new Font("Segoe UI", 8f, FontStyle.Bold);
            side.Controls.Add(l);
        }

        CheckBox Chk(string t, bool on)
        {
            CheckBox c = new CheckBox();
            c.Text = t; c.Checked = on; c.AutoSize = true; c.ForeColor = Gray; c.BackColor = Color.Transparent; c.Cursor = Cursors.Hand;
            return c;
        }

        void DoLayout()
        {
            int w = ClientSize.Width, h = ClientSize.Height, rx = SW, rw = w - rx;
            rClose = new Rectangle(w - 40, 0, 40, TB);
            rMax = new Rectangle(w - 80, 0, 40, TB);
            rMin = new Rectangle(w - 120, 0, 40, TB);
            side.SetBounds(0, TB, SW, h - TB);
            bool showLog = log.Visible;
            ring.Left = rx + (rw - ring.Width) / 2;
            ring.Top = showLog ? 116 : 150;
            status.SetBounds(rx + 10, ring.Bottom + 4, rw - 20, 24);
            log.SetBounds(rx + 16, status.Bottom + 8, rw - 32, Math.Max(40, h - status.Bottom - 8 - 44));
            cUnblock.Left = rx + 16; cUnblock.Top = h - 34;
            cKeep.Left = cUnblock.Right + 24; cKeep.Top = h - 34;
            Invalidate();
        }

        // ---------- side panel header (logo + name) ----------
        void SidePaint(object s, PaintEventArgs e)
        {
            Graphics g = e.Graphics; g.SmoothingMode = SmoothingMode.AntiAlias; g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            if (logo != null) g.DrawImage(logo, new Rectangle(18, 14, 62, 62));
            using (Font f = new Font("Segoe UI", 13f, FontStyle.Bold)) g.DrawString("Valy Launcher", f, Brushes.White, 88, 20);
            using (Font f = new Font("Segoe UI", 9f)) g.DrawString("Operator Settings", f, Brushes.Gainsboro, 90, 46);
            using (Pen p = new Pen(Color.FromArgb(50, 70, 130))) g.DrawLine(p, SW - 1, 0, SW - 1, side.Height);
        }

        // ---------- custom title bar ----------
        protected override void OnPaint(PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            int w = ClientSize.Width, h = ClientSize.Height;
            using (SolidBrush b = new SolidBrush(Bar)) g.FillRectangle(b, 0, 0, w, TB);
            using (Pen p = new Pen(Color.FromArgb(60, 80, 150))) g.DrawRectangle(p, 0, 0, w - 1, h - 1);
            using (Font f = new Font("Segoe UI", 10f, FontStyle.Bold))
            using (LinearGradientBrush b = new LinearGradientBrush(new Rectangle(14, 10, 260, 22), Cyan, Mag, 0f))
                g.DrawString("OPERATOR SETTINGS", f, b, 14, 10);
            using (Pen p = new Pen(Color.White, 1.6f))
            {
                g.DrawLine(p, rMin.Left + 14, 20, rMin.Right - 14, 20);
                g.DrawRectangle(p, rMax.Left + 14, 14, 11, 11);
                g.DrawLine(p, rClose.Left + 14, 13, rClose.Right - 14, 27);
                g.DrawLine(p, rClose.Left + 14, 27, rClose.Right - 14, 13);
            }
            using (Font f = new Font("Segoe UI", 19f, FontStyle.Bold)) g.DrawString("Scan and manage", f, Brushes.White, SW + 26, 54);
            using (Font f = new Font("Segoe UI", 9.5f)) using (SolidBrush gb = new SolidBrush(Gray))
                g.DrawString("Check, repair, update and clean up your Valy Launcher installation.", f, gb, SW + 28, 90);
            base.OnPaint(e);
        }

        void TitleDown(object s, MouseEventArgs e)
        {
            if (e.Button != MouseButtons.Left || e.Y >= TB || e.X >= ClientSize.Width - 120) return;
            ReleaseCapture();
            SendMessage(Handle, 0xA1, 2, 0); // WM_NCLBUTTONDOWN, HTCAPTION
        }

        void TitleClick(object s, MouseEventArgs e)
        {
            if (rClose.Contains(e.Location)) Close();
            else if (rMax.Contains(e.Location)) ToggleMax();
            else if (rMin.Contains(e.Location)) WindowState = FormWindowState.Minimized;
        }

        void ToggleMax()
        {
            maxed = !maxed;
            WindowState = maxed ? FormWindowState.Maximized : FormWindowState.Normal;
        }

        // ---------- scan ----------
        void StartScan()
        {
            if (running || opBusy) return;
            string ps = Path.Combine(sysDir, "Artoul-Defender.ps1");
            log.Clear(); log.Visible = true; DoLayout();
            lastReport = "";
            if (!File.Exists(ps))
            {
                Append("X  Artoul-Defender.ps1 was not found in the system folder.", Red, true);
                status.Text = "Cannot start";
                return;
            }
            running = true; spin.Start();
            status.Text = "Scanning...";
            ProcessStartInfo i = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File \"" + ps + "\" -Gui");
            i.UseShellExecute = false; i.CreateNoWindow = true; i.WorkingDirectory = dir;
            i.RedirectStandardOutput = true; i.RedirectStandardInput = true;
            i.StandardOutputEncoding = Encoding.UTF8;
            try
            {
                proc = Process.Start(i);
                proc.StandardInput.AutoFlush = true;
            }
            catch (Exception ex)
            {
                Append("X  Could not start PowerShell: " + ex.Message, Red, true);
                Finish();
                return;
            }
            Process p = proc;
            Thread t = new Thread(delegate() { Pump(p); });
            t.IsBackground = true;
            t.Start();
        }

        void Pump(Process p)
        {
            StringBuilder cur = new StringBuilder();
            StreamReader r = p.StandardOutput;
            bool lastCR = false;
            int ch;
            try
            {
                while ((ch = r.Read()) >= 0)
                {
                    char c = (char)ch;
                    if (c == '\uFEFF' || c == '\uFE0F' || char.IsSurrogate(c)) continue;
                    if (c == '\r') { lastCR = true; continue; }
                    if (c == '\n') { HandleLine(p, cur.ToString()); cur.Length = 0; lastCR = false; continue; }
                    if (lastCR) { Live(cur.ToString()); cur.Length = 0; lastCR = false; }
                    cur.Append(c);
                }
                if (cur.Length > 0) HandleLine(p, cur.ToString());
                p.WaitForExit();
            }
            catch { }
            try { BeginInvoke((MethodInvoker)delegate { Finish(); }); } catch { }
        }

        void HandleLine(Process p, string line)
        {
            if (line.Trim() == "@@ASK_UNBLOCK@@")
            {
                bool yes = false;
                try
                {
                    Invoke((MethodInvoker)delegate
                    {
                        if (cUnblock.Checked)
                            yes = MessageBox.Show(this, "Some files are still marked as downloaded from the internet (Windows may show SmartScreen warnings).\n\nUnblock them now?",
                                "Operator Settings", MessageBoxButtons.YesNo, MessageBoxIcon.Question) == DialogResult.Yes;
                    });
                }
                catch { }
                try { p.StandardInput.WriteLine(yes ? "Y" : "N"); } catch { }
                return;
            }
            Color col; bool bold;
            Classify(line, out col, out bold);
            string text = line;
            lastReport += line + "\r\n";
            try { BeginInvoke((MethodInvoker)delegate { Append(text, col, bold); }); } catch { }
        }

        void Live(string s)
        {
            string t = s.Trim();
            if (t.Length == 0) return;
            try { BeginInvoke((MethodInvoker)delegate { status.Text = t; }); } catch { }
        }

        static void Classify(string l, out Color col, out bool bold)
        {
            col = Txt; bold = false;
            string t = l.TrimStart();
            if (t.StartsWith("STEP ")) { col = Cyan; bold = true; }
            else if (t.StartsWith("\u2714") || t.StartsWith("\u2705") || t.Contains("ALL CLEAR")) { col = Green; bold = t.Contains("ALL CLEAR"); }
            else if (t.StartsWith("\u2716") || t.StartsWith("\u274C") || t.Contains("DANGER") || t.StartsWith("Do not run")) { col = Red; bold = t.Contains("DANGER"); }
            else if (t.StartsWith("\u26A0") || t.Contains("REVIEW") || t.StartsWith("Read the yellow")) { col = Yel; bold = t.Contains("REVIEW"); }
            else if (t.StartsWith("\u2022") || t.StartsWith("This is a local")) col = Gray;
            else if (t.StartsWith("\u2501")) col = Mag;
        }

        void Append(string text, Color c, bool bold)
        {
            log.SelectionStart = log.TextLength;
            log.SelectionLength = 0;
            log.SelectionColor = c;
            log.SelectionFont = bold ? fBold : fReg;
            log.AppendText(text + "\n");
            log.SelectionStart = log.TextLength;
            log.ScrollToCaret();
        }

        void Finish()
        {
            running = false; spin.Stop(); ring.Invalidate();
            status.Text = "Finished - press SCAN to run it again";
            if (cKeep.Checked)
            {
                try
                {
                    string d = Path.Combine(dir, "data");
                    if (!Directory.Exists(d)) Directory.CreateDirectory(d);
                    File.WriteAllText(Path.Combine(d, "operator-report.txt"), lastReport, Encoding.UTF8);
                }
                catch { }
            }
        }

        void ShowReport()
        {
            string f = Path.Combine(Path.Combine(dir, "data"), "operator-report.txt");
            if (!File.Exists(f)) { MessageBox.Show(this, "There is no saved report yet. Run a scan first.", "Operator Settings"); return; }
            try { Process.Start("notepad.exe", "\"" + f + "\""); } catch { }
        }

        // ---------- the round SCAN button ----------
        void RingPaint(object s, PaintEventArgs e)
        {
            Graphics g = e.Graphics;
            g.SmoothingMode = SmoothingMode.AntiAlias;
            bool busy = running || opBusy;
            Rectangle r = new Rectangle(12, 12, ring.Width - 24, ring.Height - 24);
            using (Pen back = new Pen(Color.FromArgb(40, 60, 120), 16f))
                g.DrawEllipse(back, r);
            using (Pen arc = new Pen(hover || busy ? Cyan : Color.FromArgb(0, 170, 200), 16f))
            {
                arc.StartCap = LineCap.Round; arc.EndCap = LineCap.Round;
                if (busy) g.DrawArc(arc, r, angle, 110f);
                else g.DrawArc(arc, r, -90f, 300f);
            }
            using (Font f = new Font("Segoe UI", 19f, FontStyle.Bold))
            {
                StringFormat sf = new StringFormat(); sf.Alignment = StringAlignment.Center; sf.LineAlignment = StringAlignment.Center;
                g.DrawString(busy ? "..." : "SCAN", f, hover ? Brushes.White : Brushes.Gainsboro, new RectangleF(0, 0, ring.Width, ring.Height), sf);
            }
        }

        // ---------- Plugin manager (Install / Check / Uninstall .valyp files in <app>\plugins) ----------
        string PluginDir() { return Path.Combine(dir, "plugins"); }

        static string ReadPlugin(string file, out string id, out string name, out string ver)
        {
            id = name = ver = "";
            try
            {
                if (new FileInfo(file).Length > 12L * 1024 * 1024) return "bigger than 12 MB";
                using (ZipArchive z = ZipFile.OpenRead(file))
                {
                    ZipArchiveEntry m = null; long unz = 0;
                    foreach (ZipArchiveEntry en in z.Entries)
                    {
                        unz += en.Length;
                        string nm = en.FullName.Replace('\\', '/');
                        if (nm.StartsWith("/") || nm.Contains("..")) return "unsafe path inside: " + en.FullName;
                        if (nm == "plugin.json") m = en;
                    }
                    if (unz > 40L * 1024 * 1024) return "too big when unpacked";
                    if (m == null) return "plugin.json is missing";
                    string json;
                    using (StreamReader sr = new StreamReader(m.Open(), Encoding.UTF8)) json = sr.ReadToEnd();
                    id = Jv(json, "id"); name = Jv(json, "name"); ver = Jv(json, "version");
                    if (!System.Text.RegularExpressions.Regex.IsMatch(id, "^[a-z0-9][a-z0-9_.\\-]{1,39}$")) return "plugin.json: bad \"id\" (2-40 chars: a-z 0-9 . _ -)";
                }
                return null;
            }
            catch (Exception ex) { return "cannot be read (" + ex.Message + ")"; }
        }

        static string Jv(string json, string key)
        {
            System.Text.RegularExpressions.Match m = System.Text.RegularExpressions.Regex.Match(json, "\"" + key + "\"\\s*:\\s*\"([^\"]*)\"");
            return m.Success ? m.Groups[1].Value : "";
        }

        Label DLbl(string t, int x, int y, int w, int h, float size, bool bold, Color c)
        {
            Label l = new Label();
            l.Text = t; l.SetBounds(x, y, w, h); l.ForeColor = c; l.BackColor = Color.Transparent;
            l.Font = new Font("Segoe UI", size, bold ? FontStyle.Bold : FontStyle.Regular);
            return l;
        }
        Form DForm(string title, int w, int h)
        {
            Form f = new Form();
            f.Text = title; f.ClientSize = new Size(w, h); f.StartPosition = FormStartPosition.CenterParent;
            f.FormBorderStyle = FormBorderStyle.FixedDialog; f.MaximizeBox = false; f.MinimizeBox = false;
            f.BackColor = Bg; f.Font = new Font("Segoe UI", 10f); f.Icon = Icon;
            return f;
        }

        void PluginManager()
        {
            Form f = DForm("Plugin manager", 600, 440);
            Label t = DLbl("Plugin manager", 20, 14, 540, 34, 16f, true, Cyan);
            ListBox list = new ListBox(); list.SetBounds(20, 58, 560, 240); list.BackColor = Color.FromArgb(8, 11, 24); list.ForeColor = Txt; list.BorderStyle = BorderStyle.None; list.Font = new Font("Segoe UI", 10f);
            Label info = DLbl("", 20, 306, 560, 44, 9.5f, false, Gray);
            FancyButton bi = new FancyButton("Install", 20, 372, 130, 42);
            FancyButton bc = new FancyButton("Check", 160, 372, 130, 42); bc.Ghost = true; bc.A = Cyan;
            FancyButton bu = new FancyButton("Uninstall", 300, 372, 130, 42); bu.A = Color.FromArgb(225, 70, 90); bu.B = Color.FromArgb(255, 120, 80);
            FancyButton bx = new FancyButton("Close", 450, 372, 130, 42); bx.Ghost = true; bx.A = Color.FromArgb(150, 170, 220);
            List<string> files = new List<string>();
            Action refresh = delegate
            {
                list.Items.Clear(); files.Clear();
                string d = PluginDir();
                if (Directory.Exists(d))
                    foreach (string p in Directory.GetFiles(d, "*.valyp"))
                    {
                        string id, nm, v; string err = ReadPlugin(p, out id, out nm, out v);
                        files.Add(p);
                        list.Items.Add(Path.GetFileName(p) + (err == null ? "   -   " + (nm.Length > 0 ? nm : id) + " " + v : "   -   PROBLEM"));
                    }
                info.Text = list.Items.Count == 0 ? "No plugins installed. Press Install to add a .valyp file."
                    : list.Items.Count + " plugin(s) installed. New plugins start OFF inside Valy (Settings > Plugins).";
            };
            bi.Click += delegate
            {
                using (OpenFileDialog od = new OpenFileDialog())
                {
                    od.Filter = "Valy plugin (*.valyp)|*.valyp"; od.Multiselect = true;
                    if (od.ShowDialog(f) != DialogResult.OK) return;
                    Directory.CreateDirectory(PluginDir()); int ok = 0; StringBuilder bad = new StringBuilder();
                    foreach (string p in od.FileNames)
                    {
                        string id, nm, v; string err = ReadPlugin(p, out id, out nm, out v);
                        if (err != null) { bad.AppendLine(Path.GetFileName(p) + ": " + err); continue; }
                        try { File.Copy(p, Path.Combine(PluginDir(), Path.GetFileName(p)), true); ok++; } catch (Exception ex) { bad.AppendLine(Path.GetFileName(p) + ": " + ex.Message); }
                    }
                    refresh();
                    MessageBox.Show(f, ok + " plugin(s) installed.\r\nA plugin runs with the same power as the app - turn on only plugins from people you trust." + (bad.Length > 0 ? "\r\n\r\nNot installed:\r\n" + bad : ""), "Plugins");
                }
            };
            bc.Click += delegate
            {
                StringBuilder sb = new StringBuilder(); int badN = 0;
                foreach (string p in files)
                {
                    string id, nm, v; string err = ReadPlugin(p, out id, out nm, out v);
                    if (err == null) sb.AppendLine("OK        " + Path.GetFileName(p) + "  (" + id + " " + v + ")"); else { badN++; sb.AppendLine("PROBLEM   " + Path.GetFileName(p) + "  -  " + err); }
                }
                if (files.Count == 0) sb.AppendLine("No plugins installed.");
                MessageBox.Show(f, sb.ToString() + "\r\n" + (badN == 0 ? "All good." : badN + " plugin(s) have problems."), "Plugins - Check");
            };
            bu.Click += delegate
            {
                if (list.SelectedIndex < 0) { MessageBox.Show(f, "Select a plugin in the list first.", "Plugins"); return; }
                string p = files[list.SelectedIndex];
                if (MessageBox.Show(f, "Remove " + Path.GetFileName(p) + " ?", "Uninstall plugin", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
                try { File.Delete(p); } catch (Exception ex) { MessageBox.Show(f, ex.Message, "Plugins"); }
                refresh();
            };
            bx.Click += delegate { f.Close(); };
            f.Controls.AddRange(new Control[] { t, list, info, bi, bc, bu, bx });
            refresh();
            f.ShowDialog(this);
        }

        // ---------- integrity check / repair: every file in system\manifest.sha256 (repair restores from data\recovery) ----------
        static string Hash(string f)
        {
            using (FileStream fs = File.OpenRead(f))
            {
                byte[] h = SHA256.Create().ComputeHash(fs);
                StringBuilder sb = new StringBuilder(); foreach (byte x in h) sb.Append(x.ToString("x2"));
                return sb.ToString();
            }
        }

        void ManifestCheck(bool fix)
        {
            if (running || opBusy) return;
            string mf = Path.Combine(sysDir, "manifest.sha256");
            log.Clear(); log.Visible = true; DoLayout(); lastReport = "";
            if (!File.Exists(mf))
            {
                Append("X  system\\manifest.sha256 is missing. Use 'Update app' to rebuild the integrity list.", Red, true);
                status.Text = "Integrity list is missing"; return;
            }
            Cursor = Cursors.WaitCursor;
            Append(fix ? "Repairing files from the recovery copy..." : "Checking files...", Cyan, true);
            string rec = Path.Combine(Path.Combine(dir, "data"), "recovery");
            int total = 0, okN = 0, fixedN = 0, failN = 0;
            foreach (string l in File.ReadAllLines(mf))
            {
                if (!(l.Length > 66 && l[64] == ' ' && l[65] == '*')) continue;
                total++;
                string hash = l.Substring(0, 64).ToLowerInvariant(), rel = l.Substring(66);
                string f = Path.Combine(dir, rel);
                bool ok = false;
                try { ok = File.Exists(f) && Hash(f) == hash; } catch { }
                if (ok) { okN++; continue; }
                if (!fix) { failN++; Append("!  missing or changed: " + rel, Yel, false); continue; }
                string src = Path.Combine(rec, rel); bool done = false;
                try
                {
                    if (File.Exists(src) && Hash(src) == hash)
                    {
                        Directory.CreateDirectory(Path.GetDirectoryName(f));
                        if (File.Exists(f)) File.SetAttributes(f, FileAttributes.Normal);
                        File.Copy(src, f, true);
                        if (rel.EndsWith("valy-launcher.html", StringComparison.OrdinalIgnoreCase)) File.SetAttributes(f, FileAttributes.Hidden);
                        done = true;
                    }
                }
                catch { }
                if (done) { fixedN++; Append("OK restored: " + rel, Green, false); }
                else { failN++; Append("X  could not restore: " + rel, Red, false); }
                Application.DoEvents();
            }
            Cursor = Cursors.Default;
            string sum;
            if (!fix) sum = failN == 0 ? "All " + total + " files are in place and unchanged." : failN + " file(s) missing or changed. Press Fix / Repair.";
            else if (failN == 0 && fixedN == 0) sum = "Nothing to fix. All " + total + " files are in place.";
            else if (failN == 0) sum = "Fixed " + fixedN + " file(s).";
            else sum = "Fixed " + fixedN + ", could not fix " + failN + ". Use 'Update app' to reinstall them.";
            Append(sum, failN == 0 ? Green : (fix ? Red : Yel), true);
            status.Text = sum;
            lastReport = log.Text;
            if (cKeep.Checked) { try { Directory.CreateDirectory(Path.Combine(dir, "data")); File.WriteAllText(Path.Combine(Path.Combine(dir, "data"), "operator-report.txt"), lastReport, Encoding.UTF8); } catch { } }
        }

        // ---------- updates ----------
        // Update app: pick a newer ValyLauncherSetup.exe (from the seller). It updates the same folder; this window is closed by it.
        void UpdateApp()
        {
            using (OpenFileDialog od = new OpenFileDialog())
            {
                od.Title = "Choose the new ValyLauncherSetup.exe"; od.Filter = "Valy setup (*.exe)|*.exe";
                if (od.ShowDialog(this) != DialogResult.OK) return;
                if (MessageBox.Show(this, "Run this setup to update Valy Launcher?\r\n\r\n" + od.FileName + "\r\n\r\nOperator Settings closes while the update runs. Your data is kept.", "Update app", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
                try { Process.Start(new ProcessStartInfo(od.FileName) { UseShellExecute = true, WorkingDirectory = Path.GetDirectoryName(od.FileName) }); }
                catch (Exception ex) { MessageBox.Show(this, "Could not start it: " + ex.Message, "Update app"); }
            }
        }

        void UpdateValyv()
        {
            using (OpenFileDialog od = new OpenFileDialog())
            {
                od.Title = "Choose the .valyv update file"; od.Filter = "Valy update (*.valyv)|*.valyv|All files (*.*)|*.*";
                if (od.ShowDialog(this) != DialogResult.OK) return;
                RunCore("Valyv", od.FileName, true, "Updating from " + Path.GetFileName(od.FileName));
            }
        }

        static string FindLic()
        {
            string[] ds = { AppDomain.CurrentDomain.BaseDirectory, Environment.GetFolderPath(Environment.SpecialFolder.Desktop), Path.Combine(Environment.GetEnvironmentVariable("USERPROFILE") ?? "", "Downloads") };
            foreach (string d in ds) { try { string f = Path.Combine(d, "premium.valylic"); if (File.Exists(f)) return f; foreach (string g in Directory.GetFiles(d, "premium*.valylic")) return g; } catch { } }
            return Path.Combine(ds[0], "premium.valylic");
        }

        public static string MachineId()
        {
            string g = "";
            try { using (RegistryKey b = RegistryKey.OpenBaseKey(RegistryHive.LocalMachine, RegistryView.Registry64)) using (RegistryKey k = b.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography")) g = (string)k.GetValue("MachineGuid"); } catch { }
            byte[] h = SHA256.Create().ComputeHash(Encoding.UTF8.GetBytes("valy|" + g));
            StringBuilder sb = new StringBuilder(); foreach (byte x in h) sb.Append(x.ToString("X2"));
            string t = sb.ToString().Substring(0, 16);
            return t.Substring(0, 4) + "-" + t.Substring(4, 4) + "-" + t.Substring(8, 4) + "-" + t.Substring(12, 4);
        }

        void PremiumDialog()
        {
            Form f = DForm("Update Premium", 560, 340);
            string id = MachineId();
            string lic = FindLic();
            Label t = DLbl("Valy Launcher Premium", 20, 16, 520, 36, 17f, true, Yel);
            Label l1 = DLbl("Your Machine ID - send it to the seller to get your Premium file:", 20, 66, 520, 24, 10f, false, Txt);
            TextBox tb = new TextBox(); tb.SetBounds(20, 96, 380, 30); tb.ReadOnly = true; tb.Text = id; tb.Font = new Font("Consolas", 13f); tb.BackColor = Color.FromArgb(8, 11, 24); tb.ForeColor = Color.White; tb.BorderStyle = BorderStyle.FixedSingle;
            FancyButton cp = new FancyButton("Copy", 412, 92, 128, 38); cp.Ghost = true; cp.A = Cyan;
            cp.Click += delegate { try { Clipboard.SetText(id); cp.Text = "Copied"; } catch { } };
            bool has = File.Exists(lic);
            Label l2 = DLbl(has ? "Found: " + lic : "Put premium.valylic next to this program (or in Downloads / Desktop), or press Browse, then Activate.", 20, 150, 520, 56, 10f, false, has ? Color.FromArgb(120, 255, 170) : Color.FromArgb(255, 200, 120));
            FancyButton bw = new FancyButton("Browse...", 20, 268, 130, 44); bw.Ghost = true; bw.A = Cyan;
            bw.Click += delegate
            {
                using (OpenFileDialog d = new OpenFileDialog())
                {
                    d.Filter = "Valy license (*.valylic)|*.valylic|All files|*.*";
                    if (d.ShowDialog(f) == DialogResult.OK) { lic = d.FileName; l2.Text = "Selected: " + d.FileName; l2.ForeColor = Color.FromArgb(120, 255, 170); }
                }
            };
            FancyButton go = new FancyButton("Activate", 276, 268, 150, 44); go.A = Color.FromArgb(214, 150, 20); go.B = Color.FromArgb(255, 205, 60);
            go.Click += delegate
            {
                if (!File.Exists(lic)) { MessageBox.Show(f, "premium.valylic was not found. Use Browse to pick the file.", "Update Premium"); return; }
                f.Close(); RunCore("Premium", lic, false, "Activating Premium");
            };
            FancyButton cl = new FancyButton("Close", 438, 268, 102, 44); cl.Ghost = true; cl.A = Color.FromArgb(150, 170, 220);
            cl.Click += delegate { f.Close(); };
            f.Controls.AddRange(new Control[] { t, l1, tb, cp, l2, bw, go, cl });
            f.ShowDialog(this);
        }

        // Runs system\Install-Core.ps1 -Action <Premium|Valyv> and shows its steps in the log area.
        void RunCore(string action, string file, bool keepOp, string title)
        {
            if (running || opBusy) return;
            string core = Path.Combine(sysDir, "Install-Core.ps1");
            if (!File.Exists(core)) { MessageBox.Show(this, "system\\Install-Core.ps1 was not found. Use Fix / Repair first.", "Operator Settings"); return; }
            log.Clear(); log.Visible = true; DoLayout(); lastReport = "";
            Append(title, Cyan, true);
            opBusy = true; spin.Start(); status.Text = title + "...";
            string args = "-NoProfile -ExecutionPolicy Bypass -File \"" + core + "\" -Action " + action + " -Dir \"" + dir.TrimEnd('\\') + "\" " + (action == "Premium" ? "-LicenseFile" : "-PackageFile") + " \"" + file + "\"";
            ProcessStartInfo i = new ProcessStartInfo("powershell.exe", args);
            i.UseShellExecute = false; i.CreateNoWindow = true; i.RedirectStandardOutput = true; i.StandardOutputEncoding = Encoding.UTF8; i.WorkingDirectory = dir;
            if (keepOp) i.EnvironmentVariables["VALY_KEEP_OP"] = "1";   // the update must not kill this window (it renames the old exe instead)
            Thread th = new Thread(delegate()
            {
                string fail = null;
                try
                {
                    Process p = Process.Start(i);
                    string line;
                    while ((line = p.StandardOutput.ReadLine()) != null)
                    {
                        string[] t = line.Split('|');
                        if (t[0] == "STEP" && t.Length >= 4)
                        {
                            string msg = "Step " + t[1] + "/" + t[2] + "   " + t[3];
                            try { BeginInvoke((MethodInvoker)delegate { Append(msg, Txt, false); status.Text = msg; }); } catch { }
                        }
                        else if (t[0] == "FAIL") fail = line.Substring(5);
                    }
                    p.WaitForExit();
                    if (fail == null && p.ExitCode != 0) fail = "The update program stopped with code " + p.ExitCode + ".";
                }
                catch (Exception ex) { fail = ex.Message; }
                try { BeginInvoke((MethodInvoker)delegate { OpDone(action, fail); }); } catch { }
            });
            th.IsBackground = true; th.Start();
        }

        void OpDone(string action, string fail)
        {
            opBusy = false; spin.Stop(); ring.Invalidate();
            if (fail != null)
            {
                Append("X  " + fail, Red, true); status.Text = "Failed";
                MessageBox.Show(this, fail, "Operator Settings");
                return;
            }
            Append("OK  Done.", Green, true); status.Text = "Done";
            lastReport = log.Text;
            if (action == "Valyv")
            {
                MessageBox.Show(this, "The update is finished. Operator Settings will reopen now.", "Operator Settings");
                try { Process.Start(new ProcessStartInfo(Application.ExecutablePath) { WorkingDirectory = dir, UseShellExecute = true }); } catch { }
                Close();
            }
            else MessageBox.Show(this, "Valy Launcher Premium is active. Restart Valy Launcher if it is open.", "Operator Settings");
        }

        // Uninstall: opens Valy-Uninstall.exe (the one colorless file in this folder); it asks what to delete.
        void UninstallValy()
        {
            string u = Path.Combine(dir, "Valy-Uninstall.exe");
            if (!File.Exists(u)) { UninstallDirect(); return; }
            if (MessageBox.Show(this, "Open the uninstaller?\r\n\r\nIt asks a few questions first. Nothing is deleted until you confirm there.", "Uninstall Valy", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            try { Process.Start(new ProcessStartInfo(u) { UseShellExecute = true, WorkingDirectory = dir }); Close(); }
            catch (Exception ex) { MessageBox.Show(this, "Could not open it: " + ex.Message, "Uninstall Valy"); }
        }

        // No Valy-Uninstall.exe in the folder: remove Valy straight from here with the same engine (system\Install-Core.ps1, run from a temp copy).
        void UninstallDirect()
        {
            DialogResult r = MessageBox.Show(this, "Remove Valy Launcher from this PC?\r\n\r\nYes = remove the app AND all your data (games, apps, notes, settings, songs)\r\nNo = remove the app but KEEP my data\r\nCancel = do nothing\r\n\r\nYour Premium license is kept.", "Uninstall Valy", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button3);
            if (r == DialogResult.Cancel) return;
            string wipe = r == DialogResult.Yes ? "1" : "0";
            try
            {
                string core = Path.Combine(sysDir, "Install-Core.ps1"), prem = Path.Combine(sysDir, "valy-premium.ps1");
                if (!File.Exists(core) || !File.Exists(prem)) { MessageBox.Show(this, "system\\Install-Core.ps1 was not found. Use Fix / Repair first, or remove Valy from Windows Settings > Apps.", "Uninstall Valy"); return; }
                string tmp = Path.Combine(Path.GetTempPath(), "valy-un-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(tmp);
                File.Copy(core, Path.Combine(tmp, "Install-Core.ps1"), true); File.Copy(prem, Path.Combine(tmp, "valy-premium.ps1"), true);
                foreach (Process q in Process.GetProcessesByName("ValyLauncher")) { try { q.Kill(); q.WaitForExit(1500); } catch { } }
                string d = dir.TrimEnd('\\').Replace("'", "''"), c = Path.Combine(tmp, "Install-Core.ps1").Replace("'", "''");
                string cmd = "Start-Sleep -Seconds 2; & '" + c + "' -Action Uninstall -Dir '" + d + "' -WipeData " + wipe + " -WipePlugins " + wipe + " -KeepLicense 1";
                ProcessStartInfo psi = new ProcessStartInfo("powershell.exe", "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command \"" + cmd.Replace("\"", "\\\"") + "\"");
                psi.UseShellExecute = false; psi.CreateNoWindow = true;
                Process.Start(psi);
                MessageBox.Show(this, "Valy Launcher is being removed. This window closes now.", "Uninstall Valy");
                Close();
            }
            catch (Exception ex) { MessageBox.Show(this, "Could not uninstall: " + ex.Message, "Uninstall Valy"); }
        }

        // ---------- wipe everything Valy saved: the data folder and the launcher's local save ----------
        void ClearAllData()
        {
            if (MessageBox.Show(this, "This deletes ALL your Valy data: games, apps, notes, settings, themes, songs, backgrounds and the local save of the launcher.\n\nYour Premium license is kept. This cannot be undone.\n\nClear everything?", "Operator Settings", MessageBoxButtons.YesNo, MessageBoxIcon.Warning, MessageBoxDefaultButton.Button2) != DialogResult.Yes) return;
            try
            {
                string dd = Path.Combine(dir, "data");
                int n = 0;
                if (Directory.Exists(dd))
                {
                    foreach (string f in Directory.GetFiles(dd))
                    {
                        string nm = Path.GetFileName(f).ToLowerInvariant();
                        if (nm == "premium.valylic" || nm == "bridge.json") continue;
                        try { File.SetAttributes(f, FileAttributes.Normal); File.Delete(f); n++; } catch { }
                    }
                    foreach (string d in Directory.GetDirectories(dd))
                    {
                        if (Path.GetFileName(d).ToLowerInvariant() == "recovery") continue;
                        try { Directory.Delete(d, true); n++; } catch { }
                    }
                }
                else Directory.CreateDirectory(dd);
                File.WriteAllText(Path.Combine(dd, "clear-local.flag"), "1");
                MessageBox.Show(this, "Done. Your data was cleared. If Valy Launcher is open it wipes its local save in a few seconds; otherwise it does that the next time it starts.", "Operator Settings");
            }
            catch (Exception ex) { MessageBox.Show(this, "Could not clear the data: " + ex.Message, "Operator Settings"); }
        }

        // ---------- remove the "downloaded from the internet" mark from every file of the app ----------
        void UnblockAll()
        {
            try
            {
                ProcessStartInfo i = new ProcessStartInfo("powershell.exe",
                    "-NoProfile -ExecutionPolicy Bypass -Command \"Get-ChildItem -LiteralPath '" + dir.TrimEnd('\\').Replace("'", "''") + "' -Recurse -File | Unblock-File\"");
                i.UseShellExecute = false; i.CreateNoWindow = true;
                Process p = Process.Start(i);
                p.WaitForExit(30000);
                MessageBox.Show(this, "Done. All files of Valy Launcher are unblocked.", "Operator Settings");
            }
            catch (Exception ex) { MessageBox.Show(this, "Could not unblock the files: " + ex.Message, "Operator Settings"); }
        }
    }
}
