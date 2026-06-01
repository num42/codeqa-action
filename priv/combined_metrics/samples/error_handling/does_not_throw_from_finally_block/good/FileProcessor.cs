using System;
using System.IO;

namespace FileProcessing
{
    public class FileProcessor
    {
        private readonly ILogger _logger;

        public FileProcessor(ILogger logger)
        {
            _logger = logger;
        }

        public string ReadAndProcess(string filePath)
        {
            StreamReader reader = null;
            try
            {
                reader = new StreamReader(filePath);
                var content = reader.ReadToEnd();
                return Transform(content);
            }
            catch (FileNotFoundException ex)
            {
                _logger.Error("Input file not found: {path}", ex);
                throw;
            }
            finally
            {
                // Finally only performs cleanup — never throws
                try
                {
                    reader?.Close();
                }
                catch (IOException ex)
                {
                    // Log but do not rethrow; we must not suppress the original exception
                    _logger.Warning("Failed to close reader cleanly", ex);
                }
            }
        }

        public void ProcessBatch(string[] filePaths)
        {
            FileStream lockFile = null;
            try
            {
                lockFile = AcquireLock();
                foreach (var path in filePaths)
                {
                    ProcessSingleFile(path);
                }
            }
            finally
            {
                // Cleanup only — releasing the lock must not throw out of finally
                if (lockFile != null)
                {
                    try
                    {
                        lockFile.Close();
                        File.Delete(lockFile.Name);
                    }
                    catch (IOException ex)
                    {
                        _logger.Warning("Lock file cleanup failed", ex);
                    }
                }
            }
        }

        private string Transform(string content) => content.Trim().ToUpperInvariant();

        private void ProcessSingleFile(string path)
        {
            var content = File.ReadAllText(path);
            File.WriteAllText(path + ".out", Transform(content));
        }

        private FileStream AcquireLock() =>
            new FileStream("/tmp/processor.lock", FileMode.Create, FileAccess.Write);
    }
}
