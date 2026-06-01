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

        // I/O-bound: reads directly with async file API, no Task.Run needed
        public async Task<string> ReadDocumentAsync(string documentId)
        {
            var path = BuildPath(documentId);
            return await File.ReadAllTextAsync(path);
        }

        // I/O-bound: writes via async file API
        public async Task SaveDocumentAsync(string documentId, string content)
        {
            var path = BuildPath(documentId);
            Directory.CreateDirectory(Path.GetDirectoryName(path)!);
            await File.WriteAllTextAsync(path, content, Encoding.UTF8);
        }

        // I/O-bound: uses async HttpClient, not Task.Run
        public async Task<string> FetchFromRemoteAsync(string url)
        {
            var response = await _httpClient.GetAsync(url);
            response.EnsureSuccessStatusCode();
            return await response.Content.ReadAsStringAsync();
        }

        // I/O-bound: streams large file without blocking
        public async Task DownloadToFileAsync(string url, string destinationPath)
        {
            using var response = await _httpClient.GetAsync(
                url, System.Net.Http.HttpCompletionOption.ResponseHeadersRead);
            response.EnsureSuccessStatusCode();

            using var contentStream = await response.Content.ReadAsStreamAsync();
            using var fileStream = new FileStream(
                destinationPath, FileMode.Create, FileAccess.Write, FileShare.None,
                bufferSize: 8192, useAsync: true);

            await contentStream.CopyToAsync(fileStream);
        }

        private string BuildPath(string documentId) =>
            Path.Combine(_storageRoot, documentId[..2], documentId + ".txt");
    }
}
