using System.Diagnostics;
using System.Net.Http.Json;
using System.Runtime.InteropServices;
using System.Text.Json;

var configPath = ResolveConfigPath(args);
var config = ProjectConfig.Load(configPath);

while (true)
{
    var ram = RamMonitor.GetSnapshot();
    Console.WriteLine();
    Console.WriteLine("Project Mirror Dev Beta 1 - .NET RAM Menu");
    Console.WriteLine($"Config: {configPath}");
    Console.WriteLine($"Profile: {config.Runtime.Profile}");
    Console.WriteLine($"RAM: {ram.AvailableMb:N0} MB free / {ram.TotalMb:N0} MB total");
    Console.WriteLine($"Project Mirror RAM limit: {config.Runtime.RamLimitMb:N0} MB");
    Console.WriteLine($"Low RAM alert: {config.Runtime.LowRamAlertMb:N0} MB");
    if (ram.AvailableMb <= config.Runtime.LowRamAlertMb)
    {
        Console.ForegroundColor = ConsoleColor.Yellow;
        Console.WriteLine("Alert: available RAM is below the Project Mirror threshold.");
        Console.ResetColor();
    }

    Console.WriteLine();
    Console.WriteLine("1. Set Project Mirror RAM limit");
    Console.WriteLine("2. Set low RAM alert threshold");
    Console.WriteLine("3. Change optimization profile");
    Console.WriteLine("4. Start RAM alert monitor");
    Console.WriteLine("5. Ask Node server for AI optimization plan");
    Console.WriteLine("6. Open Swift GUI");
    Console.WriteLine("7. Save and exit");
    Console.Write("Select: ");

    var choice = Console.ReadLine()?.Trim();
    Console.WriteLine();

    switch (choice)
    {
        case "1":
            config.Runtime.RamLimitMb = PromptInt("RAM limit MB", config.Runtime.RamLimitMb, 256, 262144);
            config.Save(configPath);
            Console.WriteLine("Saved RAM limit. Ruby, Node, and Python will receive it through config/env.");
            break;
        case "2":
            config.Runtime.LowRamAlertMb = PromptInt("Low RAM alert MB", config.Runtime.LowRamAlertMb, 128, 262144);
            config.Save(configPath);
            Console.WriteLine("Saved low RAM alert threshold.");
            break;
        case "3":
            config.Runtime.Profile = PromptProfile(config.Runtime.Profile);
            config.Save(configPath);
            await PushProfile(config);
            break;
        case "4":
            StartAlertMonitor(config);
            break;
        case "5":
            await RequestOptimizationPlan(config);
            break;
        case "6":
            StartSwiftGui(configPath);
            break;
        case "7":
        case "q":
        case "Q":
            config.Save(configPath);
            return;
        default:
            Console.WriteLine("Unknown selection.");
            break;
    }
}

static string ResolveConfigPath(string[] args)
{
    for (var index = 0; index < args.Length - 1; index++)
    {
        if (args[index] == "--config")
        {
            return Path.GetFullPath(args[index + 1]);
        }
    }

    var current = new DirectoryInfo(Environment.CurrentDirectory);
    while (current is not null)
    {
        var candidate = Path.Combine(current.FullName, "config", "project_mirror.json");
        if (File.Exists(candidate))
        {
            return candidate;
        }

        current = current.Parent;
    }

    return Path.GetFullPath(Path.Combine("config", "project_mirror.json"));
}

static int PromptInt(string label, int current, int min, int max)
{
    while (true)
    {
        Console.Write($"{label} [{current}]: ");
        var input = Console.ReadLine();
        if (string.IsNullOrWhiteSpace(input))
        {
            return current;
        }

        if (int.TryParse(input, out var value) && value >= min && value <= max)
        {
            return value;
        }

        Console.WriteLine($"Enter a number from {min} to {max}.");
    }
}

static string PromptProfile(string current)
{
    Console.Write($"Profile quality/balanced/performance [{current}]: ");
    var input = Console.ReadLine()?.Trim().ToLowerInvariant();
    return input is "quality" or "balanced" or "performance" ? input : current;
}

static void StartAlertMonitor(ProjectConfig config)
{
    Console.WriteLine("RAM alert monitor running. Press Esc to stop.");
    while (true)
    {
        var ram = RamMonitor.GetSnapshot();
        var stamp = DateTime.Now.ToString("HH:mm:ss");
        if (ram.AvailableMb <= config.Runtime.LowRamAlertMb)
        {
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.WriteLine($"[{stamp}] LOW RAM: {ram.AvailableMb:N0} MB free. Limit: {config.Runtime.RamLimitMb:N0} MB.");
            Console.ResetColor();
        }
        else
        {
            Console.WriteLine($"[{stamp}] RAM OK: {ram.AvailableMb:N0} MB free.");
        }

        for (var i = 0; i < Math.Max(1, config.Runtime.PollSeconds * 10); i++)
        {
            Thread.Sleep(100);
            if (Console.KeyAvailable && Console.ReadKey(intercept: true).Key == ConsoleKey.Escape)
            {
                return;
            }
        }
    }
}

static void StartSwiftGui(string configPath)
{
    var packagePath = ResolveSwiftPackagePath();
    var startInfo = new ProcessStartInfo
    {
        FileName = "swift",
        UseShellExecute = false,
        WorkingDirectory = Directory.GetCurrentDirectory()
    };
    startInfo.ArgumentList.Add("run");
    startInfo.ArgumentList.Add("--package-path");
    startInfo.ArgumentList.Add(packagePath);
    startInfo.ArgumentList.Add("ProjectMirrorGUI");
    startInfo.Environment["PROJECT_MIRROR_CONFIG"] = configPath;

    try
    {
        Process.Start(startInfo);
        Console.WriteLine("Swift GUI launched.");
    }
    catch (Exception error)
    {
        Console.WriteLine($"Swift GUI could not start: {error.Message}");
    }
}

static string ResolveSwiftPackagePath()
{
    var current = new DirectoryInfo(Environment.CurrentDirectory);
    while (current is not null)
    {
        var candidate = Path.Combine(current.FullName, "src", "swift", "ProjectMirrorGUI");
        if (Directory.Exists(candidate))
        {
            return candidate;
        }

        current = current.Parent;
    }

    return Path.GetFullPath(Path.Combine("src", "swift", "ProjectMirrorGUI"));
}
static async Task PushProfile(ProjectConfig config)
{
    try
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(2) };
        var url = $"http://{config.Server.Host}:{config.Server.Port}/api/profile";
        var response = await client.PostAsJsonAsync(url, new { profile = config.Runtime.Profile });
        Console.WriteLine(response.IsSuccessStatusCode
            ? "Profile sent to Node server."
            : $"Config saved. Node server returned {(int)response.StatusCode}.");
    }
    catch (Exception error)
    {
        Console.WriteLine($"Config saved. Node server is not reachable yet: {error.Message}");
    }
}

static async Task RequestOptimizationPlan(ProjectConfig config)
{
    var ram = RamMonitor.GetSnapshot();
    var payload = new
    {
        mode = "auto",
        video = new { input = "capture.mp4", width = 1920, height = 1080, fps = 60 },
        gameplay = new { currentFps = 58, targetFps = 60, latencyMs = 42 },
        system = new
        {
            totalRamMb = ram.TotalMb,
            freeRamMb = ram.AvailableMb,
            ramLimitMb = config.Runtime.RamLimitMb,
            lowRamAlertMb = config.Runtime.LowRamAlertMb,
            profile = config.Runtime.Profile
        }
    };

    try
    {
        using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(5) };
        var url = $"http://{config.Server.Host}:{config.Server.Port}/api/optimize";
        var response = await client.PostAsJsonAsync(url, payload);
        var text = await response.Content.ReadAsStringAsync();
        Console.WriteLine(text);
    }
    catch (Exception error)
    {
        Console.WriteLine($"Node server is not reachable: {error.Message}");
    }
}

internal sealed class ProjectConfig
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        PropertyNameCaseInsensitive = true
    };

    public string Name { get; set; } = "Project Mirror Dev Beta 1";
    public string Version { get; set; } = "1.0.0-beta1";
    public EndpointConfig Server { get; set; } = new() { Host = "127.0.0.1", Port = 4971 };
    public EndpointConfig AiApi { get; set; } = new() { Host = "127.0.0.1", Port = 4972 };
    public RuntimeConfig Runtime { get; set; } = new();
    public GuiConfig Gui { get; set; } = new();
    public Dictionary<string, JsonElement> Profiles { get; set; } = new();

    public static ProjectConfig Load(string path)
    {
        try
        {
            var text = File.ReadAllText(path);
            return JsonSerializer.Deserialize<ProjectConfig>(text, JsonOptions) ?? new ProjectConfig();
        }
        catch
        {
            return new ProjectConfig();
        }
    }

    public void Save(string path)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrWhiteSpace(directory))
        {
            Directory.CreateDirectory(directory);
        }

        File.WriteAllText(path, JsonSerializer.Serialize(this, JsonOptions) + Environment.NewLine);
    }
}

internal sealed class EndpointConfig
{
    public string Host { get; set; } = "127.0.0.1";
    public int Port { get; set; }
}

internal sealed class GuiConfig
{
    public int RefreshSeconds { get; set; } = 3;
    public int TaskLimit { get; set; } = 60;
    public bool Notifications { get; set; } = true;
}
internal sealed class RuntimeConfig
{
    public string Profile { get; set; } = "balanced";
    public int RamLimitMb { get; set; } = 4096;
    public int LowRamAlertMb { get; set; } = 1024;
    public int PollSeconds { get; set; } = 5;
    public bool NotificationsEnabled { get; set; } = true;
    public bool Msys2Compatible { get; set; } = true;
}

internal readonly record struct RamSnapshot(long TotalMb, long AvailableMb);

internal static class RamMonitor
{
    public static RamSnapshot GetSnapshot()
    {
        if (OperatingSystem.IsWindows() && TryGetWindowsMemory(out var windowsSnapshot))
        {
            return windowsSnapshot;
        }

        if (File.Exists("/proc/meminfo") && TryGetProcMeminfo(out var linuxSnapshot))
        {
            return linuxSnapshot;
        }

        var info = GC.GetGCMemoryInfo();
        var available = info.TotalAvailableMemoryBytes / 1024 / 1024;
        return new RamSnapshot(available, available);
    }

    private static bool TryGetWindowsMemory(out RamSnapshot snapshot)
    {
        var status = new MemoryStatusEx();
        status.Length = (uint)Marshal.SizeOf<MemoryStatusEx>();
        if (GlobalMemoryStatusEx(ref status))
        {
            snapshot = new RamSnapshot(
                (long)(status.TotalPhys / 1024 / 1024),
                (long)(status.AvailPhys / 1024 / 1024)
            );
            return true;
        }

        snapshot = default;
        return false;
    }

    private static bool TryGetProcMeminfo(out RamSnapshot snapshot)
    {
        long totalKb = 0;
        long availableKb = 0;
        foreach (var line in File.ReadLines("/proc/meminfo"))
        {
            if (line.StartsWith("MemTotal:", StringComparison.Ordinal))
            {
                totalKb = ParseMeminfoKb(line);
            }
            else if (line.StartsWith("MemAvailable:", StringComparison.Ordinal))
            {
                availableKb = ParseMeminfoKb(line);
            }
        }

        if (totalKb > 0 && availableKb > 0)
        {
            snapshot = new RamSnapshot(totalKb / 1024, availableKb / 1024);
            return true;
        }

        snapshot = default;
        return false;
    }

    private static long ParseMeminfoKb(string line)
    {
        var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return parts.Length >= 2 && long.TryParse(parts[1], out var value) ? value : 0;
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool GlobalMemoryStatusEx(ref MemoryStatusEx buffer);

    [StructLayout(LayoutKind.Sequential)]
    private struct MemoryStatusEx
    {
        public uint Length;
        public uint MemoryLoad;
        public ulong TotalPhys;
        public ulong AvailPhys;
        public ulong TotalPageFile;
        public ulong AvailPageFile;
        public ulong TotalVirtual;
        public ulong AvailVirtual;
        public ulong AvailExtendedVirtual;
    }
}



