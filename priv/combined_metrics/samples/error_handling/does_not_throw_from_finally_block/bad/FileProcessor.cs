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
                _logger.Error("Input file not found", ex);
                throw;
            }
            finally
            {
                reader?.Close();
                // Throws from finally — suppresses the FileNotFoundException above
                if (!File.Exists(filePath + ".processed"))
                    throw new InvalidOperationException("Processed marker missing.");
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
                lockFile?.Close();

                // Validating state inside finally and throwing — bad practice.
                // Any exception thrown during batch processing is now lost.
                var pendingCount = CountPending(filePaths);
                if (pendingCount > 0)
                    throw new InvalidOperationException(
                        $"{pendingCount} files were not processed.");
            }
        }

        private string Transform(string content) => content.Trim().ToUpperInvariant();

        private void ProcessSingleFile(string path)
        {
            var content = File.ReadAllText(path);
            File.WriteAllText(path + ".out", Transform(content));
        }

        private int CountPending(string[] filePaths)
        {
            int count = 0;
            foreach (var p in filePaths)
                if (!File.Exists(p + ".out")) count++;
            return count;
        }

        private FileStream AcquireLock() =>
            new FileStream("/tmp/processor.lock", FileMode.Create, FileAccess.Write);
    }
}
