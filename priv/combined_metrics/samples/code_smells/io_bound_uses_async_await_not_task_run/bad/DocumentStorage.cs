using System.IO;
using System.Net.Http;
using System.Text;
using System.Threading.Tasks;

namespace Storage
{
    public class DocumentStorage
    {
        private readonly HttpClient _httpClient;
        private readonly string _storageRoot;

        public DocumentStorage(HttpClient httpClient, string storageRoot)
        {
            _httpClient = httpClient;
            _storageRoot = storageRoot;
        }

        // I/O-bound but wrapped in Task.Run — wastes a thread pool thread
        public async Task<string> ReadDocumentAsync(string documentId)
        {
            var path = BuildPath(documentId);
            return await Task.Run(() => File.ReadAllText(path));
        }

        // I/O-bound write wrapped in Task.Run unnecessarily
        public async Task SaveDocumentAsync(string documentId, string content)
        {
            var path = BuildPath(documentId);
            await Task.Run(() =>
            {
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                File.WriteAllText(path, content, Encoding.UTF8);
            });
        }

        // Network I/O inside Task.Run — HttpClient is already async, Task.Run adds no value
        public async Task<string> FetchFromRemoteAsync(string url)
        {
            return await Task.Run(async () =>
            {
                var response = await _httpClient.GetAsync(url);
                response.EnsureSuccessStatusCode();
                return await response.Content.ReadAsStringAsync();
            });
        }

        // Streaming wrapped in Task.Run — unnecessary thread pool hop for I/O
        public async Task DownloadToFileAsync(string url, string destinationPath)
        {
            await Task.Run(async () =>
            {
                var response = await _httpClient.GetAsync(url);
                response.EnsureSuccessStatusCode();
                var bytes = await response.Content.ReadAsByteArrayAsync();
                File.WriteAllBytes(destinationPath, bytes);
            });
        }

        private string BuildPath(string documentId) =>
            Path.Combine(_storageRoot, documentId[..2], documentId + ".txt");
    }
}
