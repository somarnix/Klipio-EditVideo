using System.Diagnostics;
using System.IO.Compression;
using System.Reflection;
using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace KlipioSetup;

internal static class Program
{
    private const string AppName = "Klipio";
    private const string AppVersion = "2.0.22";
    private const string AppExeName = "Klipio.exe";

    [STAThread]
    private static void Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        Application.Run(new InstallerForm(InstallerLaunchOptions.Parse(args)));
    }

    private sealed record InstallerLaunchOptions(
        bool IsUpdate,
        string? InstallDirectory,
        int? WaitProcessId,
        bool SuppressLaunch)
    {
        public static InstallerLaunchOptions Parse(string[] args)
        {
            var isUpdate = false;
            string? installDirectory = null;
            int? waitProcessId = null;
            var suppressLaunch = false;
            for (var index = 0; index < args.Length; index++)
            {
                switch (args[index].ToLowerInvariant())
                {
                    case "--update":
                        isUpdate = true;
                        break;
                    case "--install-dir" when index + 1 < args.Length:
                        installDirectory = args[++index];
                        break;
                    case "--wait-pid" when index + 1 < args.Length:
                        if (int.TryParse(args[++index], out var parsed) && parsed > 0) waitProcessId = parsed;
                        break;
                    case "--no-launch":
                        suppressLaunch = true;
                        break;
                }
            }
            return new InstallerLaunchOptions(isUpdate, installDirectory, waitProcessId, suppressLaunch);
        }
    }

    private sealed class InstallerForm : Form
    {
        private readonly Panel _pageHost = new() { Dock = DockStyle.Fill };
        private readonly Label _pageTitle = new();
        private readonly Label _pageSubtitle = new();
        private readonly Button _back = new();
        private readonly Button _next = new();
        private readonly Button _cancel = new();
        private readonly ComboBox _language = new();
        private readonly CheckBox _accept = new();
        private readonly ComboBox _installDrive = new();
        private readonly TextBox _folder = new();
        private readonly CheckBox _desktop = new() { Checked = true };
        private readonly CheckBox _startMenu = new() { Checked = true };
        private readonly CheckBox _startup = new();
        private readonly Label _space = new();
        private readonly Label _summary = new();
        private readonly Label _stage = new();
        private readonly ProgressBar _progress = new();
        private readonly CheckBox _launch = new() { Checked = true };
        private readonly List<Control> _pages = [];
        private readonly InstallerLaunchOptions _launchOptions;
        private readonly string? _installedVersion;
        private readonly string? _installedLocation;
        private int _page;
        private bool _installing;
        private bool _installed;
        private bool _syncingInstallLocation;

        private sealed record InstallDriveChoice(string Label, string Folder)
        {
            public override string ToString() => Label;
        }

        private static readonly string[] Languages =
        [
            "English", "ខ្មែរ (Khmer)", "日本語 (Japanese)", "Tiếng Việt (Vietnamese)",
            "한국어 (Korean)", "中文 (Chinese)", "Svenska (Swedish)", "Filipino",
            "हिन्दी (Hindi)", "Português do Brasil", "Español", "Français", "Deutsch",
            "Italiano", "العربية", "ไทย", "Bahasa Indonesia", "Bahasa Melayu",
            "Türkçe", "Polski", "Українська", "Nederlands", "বাংলা", "اردو"
        ];
        private static readonly string[] LanguageCodes =
        [
            "en", "km", "ja", "vi", "ko", "zh", "sv", "fil", "hi", "pt_BR", "es", "fr",
            "de", "it", "ar", "th", "id", "ms", "tr", "pl", "uk", "nl", "bn", "ur"
        ];

        public InstallerForm(InstallerLaunchOptions launchOptions)
        {
            _launchOptions = launchOptions;
            (_installedVersion, _installedLocation) = DetectExistingInstallation();
            Text = $"Klipio Setup {AppVersion}";
            ClientSize = new Size(920, 610);
            MinimumSize = new Size(820, 560);
            StartPosition = FormStartPosition.CenterScreen;
            MaximizeBox = false;
            Font = new Font("Segoe UI", 10);
            BackColor = Color.White;
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
            FormClosing += (_, e) =>
            {
                if (!_installing) return;
                e.Cancel = true;
                MessageBox.Show(this, "Klipio is still being installed. Please wait.",
                    "Installation in progress", MessageBoxButtons.OK, MessageBoxIcon.Information);
            };
            Controls.Add(BuildMain());
            Controls.Add(BuildBrand());
            _folder.Text = ResolveInstallFolder(launchOptions.InstallDirectory);
            SelectInstallDriveForFolder(_folder.Text);
            LoadExistingPreferences();
            if (!launchOptions.IsUpdate && _installedVersion != null)
                Text = $"Upgrade Klipio {_installedVersion} to {AppVersion}";
            if (launchOptions.IsUpdate)
            {
                Text = $"Updating Klipio to {AppVersion}";
                _accept.Checked = true;
                Shown += async (_, _) => await InstallAsync();
            }
            else
            {
                ShowPage(0);
            }
        }

        private Control BuildBrand()
        {
            var panel = new Panel { Dock = DockStyle.Left, Width = 255, BackColor = Color.FromArgb(20, 24, 37) };
            var logo = new PictureBox
            {
                Size = new Size(88, 88), Location = new Point(28, 34), SizeMode = PictureBoxSizeMode.Zoom,
                BackColor = Color.White
            };
            using (var stream = Assembly.GetExecutingAssembly().GetManifestResourceStream("KlipioLogo.jpeg"))
                if (stream != null) logo.Image = new Bitmap(Image.FromStream(stream));
            panel.Controls.Add(logo);
            panel.Controls.Add(new Label
            {
                Text = "KLIPIO", ForeColor = Color.White, AutoSize = true, Location = new Point(27, 145),
                Font = new Font("Segoe UI", 24, FontStyle.Bold)
            });
            panel.Controls.Add(new Panel
            {
                BackColor = Color.FromArgb(34, 211, 238), Size = new Size(58, 4), Location = new Point(29, 191)
            });
            panel.Controls.Add(new Label
            {
                Text = "Create faster.\nTell better stories.", ForeColor = Color.FromArgb(203, 213, 225),
                AutoSize = true, Location = new Point(28, 215), Font = new Font("Segoe UI", 11)
            });
            panel.Controls.Add(new Label
            {
                Text = $"Windows  •  Version {AppVersion}", ForeColor = Color.FromArgb(148, 163, 184),
                Dock = DockStyle.Bottom, Height = 48, Padding = new Padding(28, 0, 0, 0)
            });
            return panel;
        }

        private Control BuildMain()
        {
            var main = new Panel { Dock = DockStyle.Fill, BackColor = Color.White };
            var header = new Panel
            {
                Dock = DockStyle.Top, Height = 92, Padding = new Padding(35, 20, 30, 8),
                BackColor = Color.FromArgb(248, 250, 252)
            };
            _pageTitle.Dock = DockStyle.Top;
            _pageTitle.Height = 34;
            _pageTitle.Font = new Font("Segoe UI", 18, FontStyle.Bold);
            _pageTitle.ForeColor = Color.FromArgb(15, 23, 42);
            _pageSubtitle.Dock = DockStyle.Fill;
            _pageSubtitle.ForeColor = Color.FromArgb(71, 85, 105);
            header.Controls.Add(_pageSubtitle);
            header.Controls.Add(_pageTitle);

            var footer = new Panel
            {
                Dock = DockStyle.Bottom, Height = 72, Padding = new Padding(28, 15, 28, 15),
                BackColor = Color.FromArgb(248, 250, 252)
            };
            _next.Text = "Next";
            _next.Dock = DockStyle.Right;
            _next.Width = 126;
            _next.FlatStyle = FlatStyle.Flat;
            _next.FlatAppearance.BorderSize = 0;
            _next.BackColor = Color.FromArgb(79, 70, 229);
            _next.ForeColor = Color.White;
            _next.Font = new Font("Segoe UI", 10, FontStyle.Bold);
            _next.Click += async (_, _) => await NextAsync();
            _back.Text = "Back";
            _back.Dock = DockStyle.Right;
            _back.Width = 106;
            _back.Click += (_, _) => ShowPage(_page - 1);
            _cancel.Text = "Cancel";
            _cancel.Dock = DockStyle.Left;
            _cancel.Width = 106;
            _cancel.Click += (_, _) => Close();
            footer.Controls.Add(_next);
            footer.Controls.Add(new Panel { Dock = DockStyle.Right, Width = 10 });
            footer.Controls.Add(_back);
            footer.Controls.Add(_cancel);

            _pageHost.Padding = new Padding(35, 26, 35, 20);
            _pages.Add(WelcomePage());
            _pages.Add(LanguagePage());
            _pages.Add(LicensePage());
            _pages.Add(OptionsPage());
            _pages.Add(ReadyPage());
            _pages.Add(InstallingPage());
            _pages.Add(FinishedPage());
            main.Controls.Add(_pageHost);
            main.Controls.Add(footer);
            main.Controls.Add(header);
            return main;
        }

        private Control WelcomePage()
        {
            var p = Page();
            if (_installedVersion != null)
            {
                AddTop(p, Heading("Klipio is already installed"),
                    Paragraph($"Setup found Klipio {_installedVersion} in {_installedLocation}. This installer will upgrade it to Klipio {AppVersion}."),
                    Gap(12), UpgradeCard("Automatic clean upgrade",
                        "Click Next and then Install. Setup will close the old app, remove all old application files, and install the complete new version automatically."),
                    Gap(16), Card("Your work stays safe",
                        "Projects, source videos, exports, and user settings are kept. Only the old installed application files are replaced."));
            }
            else
            {
                AddTop(p, Heading("Welcome to Klipio"),
                    Paragraph("A professional desktop video editor for fast cuts, animated captions, GPU rendering, and clean exports."),
                    Gap(18), Card("Everything you need is included.",
                        "Klipio includes the required media components and is ready to use after installation."),
                    Gap(20), Paragraph("Setup installs Klipio for your Windows account. Your projects and source videos stay in their original locations."));
            }
            return p;
        }

        private Control LanguagePage()
        {
            var p = Page();
            _language.DropDownStyle = ComboBoxStyle.DropDownList;
            _language.Width = 430;
            _language.Items.AddRange(Languages);
            _language.SelectedIndex = 0;
            AddTop(p, Heading("Choose your language"),
                Paragraph("Select the language used by Klipio. You can change it later in Settings → General."),
                Gap(20), Field("Application language"), Wrap(_language), Gap(18),
                Paragraph("Klipio supports left-to-right and right-to-left interfaces, including Arabic and Urdu."));
            return p;
        }

        private Control LicensePage()
        {
            var p = Page();
            var license = new TextBox
            {
                Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Height = 245,
                BackColor = Color.FromArgb(248, 250, 252), Text = LicenseText
            };
            _accept.Text = "I accept the Klipio End User License Agreement";
            _accept.AutoSize = true;
            _accept.Height = 38;
            _accept.CheckedChanged += (_, _) => Navigation();
            AddTop(p, Paragraph("Please review the terms before installing Klipio."), Gap(10), license, Gap(12), _accept);
            return p;
        }

        private Control OptionsPage()
        {
            var p = Page();
            _folder.Text = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Klipio");
            _installDrive.DropDownStyle = ComboBoxStyle.DropDownList;
            _installDrive.Width = 430;
            PopulateInstallDrives();
            _installDrive.SelectedIndexChanged += (_, _) =>
            {
                if (_syncingInstallLocation || _installDrive.SelectedItem is not InstallDriveChoice choice) return;
                _syncingInstallLocation = true;
                _folder.Text = choice.Folder;
                _syncingInstallLocation = false;
            };
            _folder.Dock = DockStyle.Fill;
            var browse = new Button { Text = "Browse…", Dock = DockStyle.Right, Width = 100 };
            browse.Click += (_, _) => Browse();
            var row = new Panel { Height = 38 };
            row.Controls.Add(_folder);
            row.Controls.Add(browse);
            foreach (var option in new[] { _desktop, _startMenu })
            {
                option.AutoSize = true;
                option.Height = 34;
            }
            _desktop.Text = "Create a Desktop shortcut";
            _startMenu.Text = "Create a Start Menu shortcut";
            _startup.Checked = false;
            _startup.Visible = false;
            _space.Height = 44;
            _space.ForeColor = Color.FromArgb(71, 85, 105);
            _folder.TextChanged += (_, _) =>
            {
                if (!_syncingInstallLocation) SelectInstallDriveForFolder(_folder.Text);
                Space();
            };
            AddTop(p,
                Paragraph("Choose the drive where the complete Klipio app will remain after setup. The setup EXE can be stored on a different drive."),
                Field("Install drive"), Wrap(_installDrive), Gap(8),
                Field("Install folder"), row, _space, Gap(10), Field("Shortcuts"),
                _desktop, _startMenu, Gap(8),
                Paragraph("Klipio does not launch automatically when Windows starts. Open it only when you click the app."));
            Space();
            return p;
        }

        private Control ReadyPage()
        {
            var p = Page();
            _summary.Dock = DockStyle.Fill;
            _summary.Font = new Font("Segoe UI", 10.5f);
            _summary.ForeColor = Color.FromArgb(30, 41, 59);
            p.Controls.Add(_summary);
            return p;
        }

        private Control InstallingPage()
        {
            var p = Page();
            _stage.Text = "Preparing installation…";
            _stage.Height = 62;
            _stage.Font = new Font("Segoe UI", 13, FontStyle.Bold);
            _progress.Height = 16;
            _progress.Style = ProgressBarStyle.Continuous;
            AddTop(p, Heading("Installing Klipio"),
                Paragraph("Please keep this window open while application and media components are installed."),
                Gap(34), _stage, _progress);
            return p;
        }

        private Control FinishedPage()
        {
            var p = Page();
            _launch.Text = "Launch Klipio now";
            _launch.AutoSize = true;
            _launch.Height = 36;
            AddTop(p, Heading("✓ Klipio was installed successfully"),
                Paragraph("Klipio is ready. Your existing videos and project files were not moved or changed."),
                Gap(22), _launch, Gap(14),
                Card("Ready to create", "Open Klipio, create a project, then add or drag video files into the media panel."));
            return p;
        }

        private static Panel Page() => new() { Dock = DockStyle.Fill, AutoScroll = true, BackColor = Color.White };
        private static Panel Gap(int height) => new() { Height = height };
        private static void AddTop(Panel panel, params Control[] controls)
        {
            for (var i = controls.Length - 1; i >= 0; i--)
            {
                controls[i].Dock = DockStyle.Top;
                panel.Controls.Add(controls[i]);
            }
        }
        private static Control Wrap(Control control)
        {
            var panel = new Panel { Height = 42 };
            control.Location = new Point(0, 2);
            panel.Controls.Add(control);
            return panel;
        }
        private static Label Heading(string text) => new()
        {
            Text = text, Height = 46, Font = new Font("Segoe UI", 20, FontStyle.Bold), ForeColor = Color.FromArgb(15, 23, 42)
        };
        private static Label Field(string text) => new()
        {
            Text = text, Height = 30, Font = new Font("Segoe UI", 10, FontStyle.Bold), ForeColor = Color.FromArgb(30, 41, 59)
        };
        private static Label Paragraph(string text) => new()
        {
            Text = text, Height = 58, ForeColor = Color.FromArgb(71, 85, 105)
        };
        private static Panel Card(string title, string body)
        {
            var panel = new Panel { Height = 100, Padding = new Padding(16), BackColor = Color.FromArgb(239, 246, 255) };
            panel.Controls.Add(new Label { Text = body, Dock = DockStyle.Fill, ForeColor = Color.FromArgb(51, 65, 85) });
            panel.Controls.Add(new Label
            {
                Text = title, Dock = DockStyle.Top, Height = 28, Font = new Font("Segoe UI", 11, FontStyle.Bold),
                ForeColor = Color.FromArgb(30, 64, 175)
            });
            return panel;
        }

        private static Panel UpgradeCard(string title, string body)
        {
            var panel = new Panel { Height = 112, Padding = new Padding(16), BackColor = Color.FromArgb(245, 243, 255) };
            panel.Controls.Add(new Label
            {
                Text = body, Dock = DockStyle.Fill, ForeColor = Color.FromArgb(67, 56, 105), AutoEllipsis = true
            });
            panel.Controls.Add(new Label
            {
                Text = $"✓  {title}", Dock = DockStyle.Top, Height = 30,
                Font = new Font("Segoe UI", 11, FontStyle.Bold), ForeColor = Color.FromArgb(109, 40, 217)
            });
            return panel;
        }

        private void ShowPage(int index)
        {
            if (index < 0 || index >= _pages.Count) return;
            _page = index;
            _pageHost.Controls.Clear();
            _pageHost.Controls.Add(_pages[index]);
            string[] titles = ["Welcome", "Language", "License Agreement", "Installation Options", "Ready to Install", "Installing", "Finished"];
            string[] subtitles =
            [
                "Welcome to the Klipio setup experience.", "Choose how Klipio communicates with you.",
                "Review the agreement for using Klipio.", "Choose the install folder, shortcuts, and startup behavior.",
                "Review your choices before installation begins.", "Application files are being installed safely.",
                "Installation completed successfully."
            ];
            _pageTitle.Text = titles[index];
            _pageSubtitle.Text = subtitles[index];
            if (index == 4) Summary();
            Navigation();
        }

        private void Navigation()
        {
            _back.Visible = _page is > 0 and < 5 && !_installed;
            _cancel.Visible = !_installed && _page < 5;
            _next.Visible = _page != 5;
            _next.Enabled = !_installing && (_page != 2 || _accept.Checked);
            _next.Text = _page switch { 4 => "Install", 6 => "Finish", _ => "Next" };
        }

        private async Task NextAsync()
        {
            if (_page == 2 && !_accept.Checked) return;
            if (_page == 3 && string.IsNullOrWhiteSpace(_folder.Text))
            {
                MessageBox.Show(this, "Choose a valid installation folder.", "Install location", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            if (_page == 4) { await InstallAsync(); return; }
            if (_page == 6)
            {
                var exe = Path.Combine(_folder.Text, AppExeName);
                if (_launch.Checked && File.Exists(exe)) Process.Start(new ProcessStartInfo(exe)
                {
                    WorkingDirectory = _folder.Text, UseShellExecute = true
                });
                Close();
                return;
            }
            ShowPage(_page + 1);
        }

        private void Browse()
        {
            using var picker = new FolderBrowserDialog
            {
                Description = "Choose where Klipio will be installed", SelectedPath = _folder.Text, UseDescriptionForTitle = true
            };
            if (picker.ShowDialog(this) == DialogResult.OK) _folder.Text = Path.Combine(picker.SelectedPath, "Klipio");
        }

        private void PopulateInstallDrives()
        {
            _installDrive.Items.Clear();
            var systemRoot = Path.GetPathRoot(Environment.GetFolderPath(Environment.SpecialFolder.Windows)) ?? "C:\\";
            var defaultFolder = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Klipio");
            foreach (var drive in DriveInfo.GetDrives().Where(item => item.IsReady))
            {
                var root = drive.RootDirectory.FullName;
                var isSystem = string.Equals(root, systemRoot, StringComparison.OrdinalIgnoreCase);
                var type = drive.DriveType switch
                {
                    DriveType.Fixed => "internal drive",
                    DriveType.Removable => "removable drive",
                    DriveType.Network => "network drive",
                    _ => "available drive"
                };
                var label = $"{root.TrimEnd(Path.DirectorySeparatorChar)} — {type}{(isSystem ? " (recommended)" : "")}";
                var folder = isSystem ? defaultFolder : Path.Combine(root, "Klipio App");
                _installDrive.Items.Add(new InstallDriveChoice(label, folder));
            }
            SelectInstallDriveForFolder(_folder.Text);
        }

        private void SelectInstallDriveForFolder(string folder)
        {
            string? root = null;
            try { root = Path.GetPathRoot(Path.GetFullPath(folder)); }
            catch { }
            _syncingInstallLocation = true;
            _installDrive.SelectedIndex = -1;
            if (!string.IsNullOrWhiteSpace(root))
            {
                for (var index = 0; index < _installDrive.Items.Count; index++)
                {
                    if (_installDrive.Items[index] is InstallDriveChoice choice &&
                        string.Equals(Path.GetPathRoot(choice.Folder), root, StringComparison.OrdinalIgnoreCase))
                    {
                        _installDrive.SelectedIndex = index;
                        break;
                    }
                }
            }
            _syncingInstallLocation = false;
        }

        private static string ResolveInstallFolder(string? requestedFolder)
        {
            if (!string.IsNullOrWhiteSpace(requestedFolder))
                return Path.GetFullPath(requestedFolder).TrimEnd(Path.DirectorySeparatorChar);
            // A user-launched full setup always starts at the safe internal
            // per-user location and shows the drive selector. Never silently
            // reuse a removable drive from an older installation. Automatic
            // updates pass --install-dir and therefore stay at their current
            // explicitly installed location.
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Programs", "Klipio");
        }

        private static (string? Version, string? Location) DetectExistingInstallation()
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio");
                var version = (key?.GetValue("DisplayVersion") as string)?.Trim();
                var location = (key?.GetValue("InstallLocation") as string)?.Trim();
                if (!string.IsNullOrWhiteSpace(location) &&
                    File.Exists(Path.Combine(location, AppExeName)))
                    return (string.IsNullOrWhiteSpace(version) ? "(version unknown)" : version, location);
            }
            catch { }
            return (null, null);
        }

        private void LoadExistingPreferences()
        {
            var install = _folder.Text;
            var desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Klipio.lnk");
            var startPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu), "Programs", "Klipio.lnk");
            if (Directory.Exists(install))
            {
                _desktop.Checked = File.Exists(desktopPath);
                _startMenu.Checked = File.Exists(startPath);
                var languageFile = Path.Combine(install, "klipio-language.txt");
                if (File.Exists(languageFile))
                {
                    var code = File.ReadAllText(languageFile).Trim();
                    var index = Array.IndexOf(LanguageCodes, code);
                    if (index >= 0) _language.SelectedIndex = index;
                }
            }

            _startup.Checked = false;
        }

        private void Space()
        {
            var available = 0L;
            try
            {
                var root = Path.GetPathRoot(_folder.Text);
                if (!string.IsNullOrWhiteSpace(root)) available = new DriveInfo(root).AvailableFreeSpace;
            }
            catch { }
            _space.Text = $"Required: {Bytes(PayloadSize())}    •    " +
                (available > 0 ? $"Available: {Bytes(available)}" : "Disk space is checked before install");
        }

        private void Summary()
        {
            var shortcuts = new List<string>();
            if (_desktop.Checked) shortcuts.Add("Desktop");
            if (_startMenu.Checked) shortcuts.Add("Start Menu");
            _summary.Text = $"Klipio version\r\n    {AppVersion}\r\n\r\nInstallation folder\r\n    {_folder.Text}" +
                (_installedVersion == null ? "" : $"\r\n\r\nUpgrade\r\n    Remove Klipio {_installedVersion} application files, then install {AppVersion}") +
                $"\r\n\r\nRequired storage\r\n    {Bytes(PayloadSize())}" +
                "\r\n\r\nIncluded components\r\n    Klipio desktop app, FFmpeg media tools, caption engine integration" +
                $"\r\n\r\nShortcuts\r\n    {(shortcuts.Count == 0 ? "None" : string.Join(", ", shortcuts))}" +
                "\r\n\r\nLaunch at Windows sign-in\r\n    Off";
        }

        private async Task InstallAsync()
        {
            _installing = true;
            ShowPage(5);
            try
            {
                Progress(5, "Checking available disk space…");
                await Task.Run(() => CheckSpace(_folder.Text));
                Progress(12, _launchOptions.IsUpdate
                    ? "Closing Klipio and removing the previous app version…"
                    : "Closing the installed Klipio app…");
                await Task.Run(() => CloseRunningApp(_folder.Text, _launchOptions.WaitProcessId));
                Progress(20, "Verifying the installer package…");
                await Task.Run(() => InstallTransactional(_folder.Text, value =>
                    BeginInvoke(() => Progress(20 + (int)(value * 58), "Installing application and media components…"))));
                await File.WriteAllTextAsync(Path.Combine(_folder.Text, "klipio-language.txt"),
                    LanguageCodes[Math.Max(0, _language.SelectedIndex)]);
                Progress(82, "Creating shortcuts…");
                await Task.Run(() => CreateShortcuts(_folder.Text, _desktop.Checked, _startMenu.Checked));
                Progress(90, "Applying startup preference…");
                await Task.Run(() => SetStartup(_folder.Text, false));
                Progress(95, "Registering Klipio with Windows…");
                await Task.Run(() => RegisterUninstall(_folder.Text));
                Progress(100, "Klipio installed successfully.");
                _installing = false;
                _installed = true;
                ShowPage(6);
                if (_launchOptions.IsUpdate)
                {
                    if (!_launchOptions.SuppressLaunch) LaunchInstalledApp(_folder.Text);
                    Close();
                }
            }
            catch (Exception ex)
            {
                _installing = false;
                MessageBox.Show(this, $"Klipio could not be installed. No incomplete update was kept.\r\n\r\n{ex.Message}",
                    "Installation failed", MessageBoxButtons.OK, MessageBoxIcon.Error);
                ShowPage(4);
            }
        }

        private static void LaunchInstalledApp(string folder)
        {
            var exe = Path.Combine(folder, AppExeName);
            if (!File.Exists(exe)) return;
            Process.Start(new ProcessStartInfo(exe)
            {
                WorkingDirectory = folder,
                UseShellExecute = true
            });
        }

        private void Progress(int value, string stage)
        {
            _progress.Value = Math.Clamp(value, 0, 100);
            _stage.Text = stage;
            _stage.Refresh();
        }
    }

    private static long PayloadSize()
    {
        using var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("KlipioApp.zip");
        return resource?.Length ?? 0;
    }

    private static void CheckSpace(string folder)
    {
        var root = Path.GetPathRoot(Path.GetFullPath(folder));
        if (string.IsNullOrWhiteSpace(root)) throw new IOException("The installation drive is invalid.");
        var required = Math.Max(PayloadSize() * 3, 500L * 1024 * 1024);
        if (new DriveInfo(root).AvailableFreeSpace < required)
            throw new IOException($"Not enough free disk space. At least {Bytes(required)} is required.");
    }

    private static void InstallTransactional(string folder, Action<double> report)
    {
        var install = Path.GetFullPath(folder).TrimEnd(Path.DirectorySeparatorChar);
        ValidateInstallTarget(install);
        var parent = Directory.GetParent(install)?.FullName ?? throw new IOException("The installation folder is invalid.");
        Directory.CreateDirectory(parent);
        var stage = Path.Combine(parent, $".klipio-stage-{Guid.NewGuid():N}");
        var backup = Path.Combine(parent, $".klipio-backup-{Guid.NewGuid():N}");
        Directory.CreateDirectory(stage);
        try
        {
            using var resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("KlipioApp.zip")
                ?? throw new InvalidOperationException("The installer payload is missing.");
            using var archive = new ZipArchive(resource, ZipArchiveMode.Read);
            for (var i = 0; i < archive.Entries.Count; i++)
            {
                var entry = archive.Entries[i];
                var destination = Path.GetFullPath(Path.Combine(stage, entry.FullName));
                if (!destination.StartsWith(stage + Path.DirectorySeparatorChar, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("The installer contains an unsafe file path.");
                if (string.IsNullOrEmpty(entry.Name)) Directory.CreateDirectory(destination);
                else
                {
                    Directory.CreateDirectory(Path.GetDirectoryName(destination)!);
                    entry.ExtractToFile(destination, true);
                }
                report((i + 1d) / Math.Max(1, archive.Entries.Count));
            }
            if (!File.Exists(Path.Combine(stage, AppExeName))) throw new InvalidDataException("Klipio.exe is missing from the installer payload.");
            if (!File.Exists(Path.Combine(stage, "data", "app.so")) ||
                !File.Exists(Path.Combine(stage, "data", "icudtl.dat")) ||
                !Directory.Exists(Path.Combine(stage, "data", "flutter_assets")))
                throw new InvalidDataException("The Flutter runtime data folder is missing or incorrectly packaged.");
            WriteUninstaller(stage);
            if (Directory.Exists(install)) Directory.Move(install, backup);
            Directory.Move(stage, install);
            if (Directory.Exists(backup))
            {
                try { DeleteDirectory(backup); }
                catch
                {
                    // The new version is already installed. Antivirus/indexing
                    // can briefly keep an old DLL open, so finish cleanup on
                    // the next reboot instead of reporting a failed update.
                    ScheduleDirectoryDeletionOnReboot(backup);
                }
            }
        }
        catch
        {
            if (Directory.Exists(stage)) DeleteDirectory(stage);
            if (!Directory.Exists(install) && Directory.Exists(backup)) Directory.Move(backup, install);
            throw;
        }
    }

    private static void ValidateInstallTarget(string install)
    {
        var root = Path.GetPathRoot(install)?.TrimEnd(Path.DirectorySeparatorChar);
        if (string.IsNullOrWhiteSpace(root) ||
            string.Equals(root, install, StringComparison.OrdinalIgnoreCase))
            throw new IOException("Klipio cannot be installed directly into a drive root.");

        if (!Directory.Exists(install)) return;
        using var entries = Directory.EnumerateFileSystemEntries(install).GetEnumerator();
        if (!entries.MoveNext()) return;
        if (!File.Exists(Path.Combine(install, AppExeName)) &&
            !File.Exists(Path.Combine(install, "Uninstall Klipio.cmd")))
            throw new IOException("The selected folder contains files that do not belong to Klipio. Choose a dedicated Klipio folder.");
    }

    private static void CloseRunningApp(string folder, int? requestedProcessId)
    {
        var install = Path.GetFullPath(folder).TrimEnd(Path.DirectorySeparatorChar);
        var processes = Process.GetProcessesByName("Klipio").ToList();
        if (requestedProcessId is > 0)
        {
            try
            {
                var requested = Process.GetProcessById(requestedProcessId.Value);
                if (processes.All(process => process.Id != requested.Id)) processes.Add(requested);
                else requested.Dispose();
            }
            catch (ArgumentException) { }
        }

        foreach (var process in processes)
        {
            try
            {
                var path = process.MainModule?.FileName;
                if (string.IsNullOrWhiteSpace(path) || !IsInsideDirectory(path, install)) continue;
                process.CloseMainWindow();
                if (!process.WaitForExit(5000)) { process.Kill(true); process.WaitForExit(5000); }
            }
            catch (InvalidOperationException) { }
            catch (System.ComponentModel.Win32Exception) { }
            finally { process.Dispose(); }
        }
    }

    private static bool IsInsideDirectory(string path, string directory)
    {
        var candidate = Path.GetFullPath(path);
        var parent = Path.GetFullPath(directory).TrimEnd(Path.DirectorySeparatorChar) + Path.DirectorySeparatorChar;
        return candidate.StartsWith(parent, StringComparison.OrdinalIgnoreCase);
    }

    private static void CreateShortcuts(string folder, bool desktop, bool startMenu)
    {
        var exe = Path.Combine(folder, AppExeName);
        if (!File.Exists(exe)) throw new FileNotFoundException("Installed Klipio.exe was not found.", exe);
        var desktopPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), "Klipio.lnk");
        var startPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.StartMenu), "Programs", "Klipio.lnk");
        if (desktop) Shortcut(desktopPath, exe, folder); else if (File.Exists(desktopPath)) File.Delete(desktopPath);
        if (startMenu) Shortcut(startPath, exe, folder); else if (File.Exists(startPath)) File.Delete(startPath);
    }

    private static void Shortcut(string path, string target, string workingDirectory)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var shellType = Type.GetTypeFromProgID("WScript.Shell") ?? throw new InvalidOperationException("Shortcut service is unavailable.");
        dynamic shell = Activator.CreateInstance(shellType)!;
        dynamic shortcut = shell.CreateShortcut(path);
        shortcut.TargetPath = target;
        shortcut.WorkingDirectory = workingDirectory;
        shortcut.IconLocation = target;
        shortcut.Description = "Klipio video editor";
        shortcut.Save();
        Marshal.FinalReleaseComObject(shortcut);
        Marshal.FinalReleaseComObject(shell);
    }

    private static void SetStartup(string folder, bool enabled)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        if (enabled) key?.SetValue(AppName, $"\"{Path.Combine(folder, AppExeName)}\"");
        else key?.DeleteValue(AppName, false);
    }

    private static void RegisterUninstall(string folder)
    {
        using var key = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio");
        if (key == null) return;
        key.SetValue("DisplayName", AppName);
        key.SetValue("DisplayVersion", AppVersion);
        key.SetValue("Publisher", "Klipio");
        key.SetValue("InstallLocation", folder);
        key.SetValue("DisplayIcon", Path.Combine(folder, AppExeName));
        key.SetValue("UninstallString", $"cmd.exe /c \"{Path.Combine(folder, "Uninstall Klipio.cmd")}\"");
        key.SetValue("EstimatedSize", (int)Math.Min(int.MaxValue, DirectorySize(folder) / 1024), RegistryValueKind.DWord);
        key.SetValue("NoModify", 1, RegistryValueKind.DWord);
        key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
    }

    private static void WriteUninstaller(string folder) => File.WriteAllText(Path.Combine(folder, "Uninstall Klipio.cmd"),
        """
        @echo off
        set "APPDIR=%~dp0"
        powershell -NoProfile -ExecutionPolicy Bypass -Command "$desktop=[Environment]::GetFolderPath('DesktopDirectory'); $start=[Environment]::GetFolderPath('StartMenu'); Remove-Item -LiteralPath (Join-Path $desktop 'Klipio.lnk') -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath (Join-Path $start 'Programs\Klipio.lnk') -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Klipio' -Force -ErrorAction SilentlyContinue; Remove-Item -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Klipio' -Recurse -Force -ErrorAction SilentlyContinue"
        cd /d "%TEMP%"
        timeout /t 1 /nobreak >nul
        rmdir /s /q "%APPDIR%"
        """);

    private static void DeleteDirectory(string path)
    {
        for (var i = 1; i <= 8; i++)
        {
            try { Directory.Delete(path, true); return; }
            catch (IOException) when (i < 8) { Thread.Sleep(350); }
            catch (UnauthorizedAccessException) when (i < 8) { Thread.Sleep(350); }
        }
        Directory.Delete(path, true);
    }

    private static void ScheduleDirectoryDeletionOnReboot(string path)
    {
        if (!Directory.Exists(path)) return;
        foreach (var file in Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories))
            MoveFileEx(file, null, MoveFileDelayUntilReboot);
        foreach (var directory in Directory.EnumerateDirectories(path, "*", SearchOption.AllDirectories)
                     .OrderByDescending(value => value.Length))
            MoveFileEx(directory, null, MoveFileDelayUntilReboot);
        MoveFileEx(path, null, MoveFileDelayUntilReboot);
    }

    private const int MoveFileDelayUntilReboot = 0x4;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool MoveFileEx(string existingFileName, string? newFileName, int flags);

    private static long DirectorySize(string path) => Directory.EnumerateFiles(path, "*", SearchOption.AllDirectories)
        .Sum(file => { try { return new FileInfo(file).Length; } catch { return 0; } });
    private static string Bytes(long value) => value >= 1024L * 1024 * 1024
        ? $"{value / (1024d * 1024 * 1024):0.0} GB" : $"{value / (1024d * 1024):0.0} MB";

    private const string LicenseText = """
        KLIPIO END USER LICENSE AGREEMENT

        By installing Klipio, you agree to use the software only for lawful video editing and media production.

        1. LICENSE. Klipio grants you a limited, non-exclusive license to install and use the app on devices you control.

        2. YOUR CONTENT. You keep ownership of videos, audio, captions, projects, and other content you create or import. You are responsible for having the rights needed to use that content.

        3. THIRD-PARTY COMPONENTS. Klipio includes media components such as FFmpeg. Their applicable open-source notices and licenses remain in effect.

        4. UPDATES. Klipio may offer updates for security, compatibility, performance, or features. Update installation remains under your control unless you enable automatic updates.

        5. WARRANTY AND LIABILITY. The software is provided as available to the maximum extent permitted by applicable law. Keep backups of important projects and source files.

        6. UNINSTALL. You may uninstall Klipio at any time. Uninstalling does not intentionally remove your project folders or source media.

        This EULA must be reviewed by qualified legal counsel before public commercial distribution.
        """;
}
