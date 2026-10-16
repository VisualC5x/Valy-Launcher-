using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.Cryptography;
using System.Text;
#if !DEFENDER
using System.Windows.Forms;
#endif
[assembly: System.Reflection.AssemblyTitle("Valy Launcher")]
[assembly: System.Reflection.AssemblyProduct("Valy Launcher")]
[assembly: System.Reflection.AssemblyCompany("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyCopyright("VisualC5 [LNTB017]")]
[assembly: System.Reflection.AssemblyVersion("3.2.2.0")]
[assembly: System.Reflection.AssemblyFileVersion("3.2.2.0")]
// Tiny .exe wrapper: runs the PowerShell script that sits next to it, with no console window.
// ValyLauncher.exe -> valy-helper.ps1   (OperatorSettings.exe is built from OperatorSettings.cs - a normal window, no console; it is separate from the setup)
// ValyLauncher.exe first checks that the critical files still carry the SELLER's signature (public key is embedded in this exe).
static class P
{
#if !DEFENDER
    static readonly string[] Critical = { "valy-launcher.html", "valy-helper.ps1", "valy-pub.xml", "valy-premium.ps1" };

    // valy-launcher.html is also embedded inside this exe (resource "html", built from the SAME signed file).
    // If the copy next to the exe is missing or different, the embedded one is written back before the signature check.
    static void RestoreHtml(string d)
    {
        try
        {
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("html"))
            {
                if (s == null) return;
                byte[] emb;
                using (MemoryStream ms = new MemoryStream()) { s.CopyTo(ms); emb = ms.ToArray(); }
                string f = Path.Combine(d, "valy-launcher.html");
                bool same = false;
                if (File.Exists(f))
                {
                    using (SHA256 h = SHA256.Create())
                        same = Convert.ToBase64String(h.ComputeHash(File.ReadAllBytes(f))) == Convert.ToBase64String(h.ComputeHash(emb));
                    if (!same) File.SetAttributes(f, FileAttributes.Normal);
                }
                if (!same) File.WriteAllBytes(f, emb);
            }
        }
        catch { }
    }

    static bool Verify(string d)
    {
        try
        {
            string pub;
            using (Stream s = Assembly.GetExecutingAssembly().GetManifestResourceStream("pub"))
            using (StreamReader r = new StreamReader(s)) pub = r.ReadToEnd();
            // the key file next to us must be the same key that is built into this exe
            string disk = File.ReadAllText(Path.Combine(d, "valy-pub.xml"));
            if (disk.Trim() != pub.Trim()) return false;
            StringBuilder sb = new StringBuilder();
            using (SHA256 h = SHA256.Create())
                foreach (string n in Critical)
                {
                    byte[] hh = h.ComputeHash(File.ReadAllBytes(Path.Combine(d, n)));
                    sb.Append(n).Append(':').Append(BitConverter.ToString(hh).Replace("-", "").ToLowerInvariant()).Append('\n');
                }
            byte[] sig = Convert.FromBase64String(File.ReadAllText(Path.Combine(d, "package.sig")).Trim());
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider())
            {
                rsa.FromXmlString(pub);
                return rsa.VerifyData(Encoding.UTF8.GetBytes(sb.ToString()), "SHA256", sig);
            }
        }
        catch { return false; }
    }
#endif

    [STAThread]
    static void Main(string[] a)
    {
        string root = AppDomain.CurrentDomain.BaseDirectory;
        string d = Path.Combine(root, "system");   // scripts, html and keys live in the system folder
#if DEFENDER
        string ps = Path.Combine(d, "Artoul-Defender.ps1"); bool hide = false;
#else
        string ps = Path.Combine(d, "valy-helper.ps1"); bool hide = true;
        RestoreHtml(d);
        if (!Verify(d))
        {
            MessageBox.Show("Valy Launcher files were modified or damaged.\nPlease reinstall using the original setup.", "Valy Launcher", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            return;
        }
#endif
        string args = "-NoProfile -STA -ExecutionPolicy Bypass " + (hide ? "-WindowStyle Hidden " : "") + "-File \"" + ps + "\"";
        if (a.Length > 0) args += " -Arg \"" + a[0].Replace("\"", "") + "\"";
        ProcessStartInfo i = new ProcessStartInfo("powershell.exe", args) { UseShellExecute = false, CreateNoWindow = hide, WorkingDirectory = root };
        Process.Start(i);
    }
}
