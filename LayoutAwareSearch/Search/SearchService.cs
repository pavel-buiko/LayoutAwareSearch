using System.Threading.Tasks;

namespace LayoutAwareSearch.Search;

internal sealed class SearchService
{
    private readonly ApplicationCatalog _catalog = new();

    public Task<ApplicationEntry[]> WarmUpAsync() => _catalog.GetApplicationsAsync();

    public async Task<ApplicationMatch[]> FindAsync(string query)
    {
        var queries = KeyboardLayoutConverter.GetQueries(query);
        if (queries.Length == 0)
        {
            return [];
        }

        return ApplicationSearch.Find(await _catalog.GetApplicationsAsync(), queries);
    }
}
