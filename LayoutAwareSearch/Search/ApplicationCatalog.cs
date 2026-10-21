using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using Windows.Management.Deployment;

namespace LayoutAwareSearch.Search;

internal sealed class ApplicationCatalog
{
    private readonly object _gate = new();
    private Task<ApplicationEntry[]>? _refresh;
    private DateTime _refreshedAt = DateTime.MinValue;

    public Task<ApplicationEntry[]> GetApplicationsAsync()
    {
        lock (_gate)
        {
            if (_refresh is null || (_refresh.IsCompleted && DateTime.UtcNow - _refreshedAt > TimeSpan.FromMinutes(2)))
            {
                _refreshedAt = DateTime.UtcNow;
                _refresh = Task.Run(BuildIndexAsync);
            }

            return _refresh;
        }
    }

    private static async Task<ApplicationEntry[]> BuildIndexAsync()
    {
        var entries = new List<ApplicationEntry>();
        foreach (var folder in new[] { Environment.SpecialFolder.Programs, Environment.SpecialFolder.CommonPrograms })
        {
            var path = Environment.GetFolderPath(folder);
            if (!Directory.Exists(path))
            {
                continue;
            }

            try
            {
                var options = new EnumerationOptions { RecurseSubdirectories = true, IgnoreInaccessible = true };
                foreach (var shortcut in Directory.EnumerateFiles(path, "*", options))
                {
                    if (Path.GetExtension(shortcut).Equals(".lnk", StringComparison.OrdinalIgnoreCase)
                        || Path.GetExtension(shortcut).Equals(".appref-ms", StringComparison.OrdinalIgnoreCase))
                    {
                        entries.Add(new(Path.GetFileNameWithoutExtension(shortcut), shortcut));
                    }
                }
            }
            catch (IOException exception)
            {
                Debug.WriteLine(exception);
            }
        }

        try
        {
            var manager = new PackageManager();
            foreach (var package in manager.FindPackagesForUser(string.Empty))
            {
                try
                {
                    if (package.IsFramework || package.IsResourcePackage)
                    {
                        continue;
                    }

                    foreach (var app in await package.GetAppListEntriesAsync())
                    {
                        var name = app.DisplayInfo.DisplayName;
                        if (!string.IsNullOrWhiteSpace(name))
                        {
                            entries.Add(new(name, app.AppUserModelId, true));
                        }
                    }
                }
                catch (Exception exception) when (exception is System.Runtime.InteropServices.COMException
                    or UnauthorizedAccessException or InvalidOperationException)
                {
                    // Packages can disappear during an update; keep the rest of the index usable.
                    Debug.WriteLine(exception);
                }
            }
        }
        catch (Exception exception) when (exception is System.Runtime.InteropServices.COMException or UnauthorizedAccessException)
        {
            Debug.WriteLine(exception);
        }

        return entries.DistinctBy(app => app.Target, StringComparer.OrdinalIgnoreCase)
            .OrderBy(app => app.Name, StringComparer.CurrentCultureIgnoreCase).ToArray();
    }
}
