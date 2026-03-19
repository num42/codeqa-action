using System;
using System.Data.SqlClient;
using System.IO;
using System.Text;

namespace Reporting
{
    public class ReportExporter
    {
        private readonly string _connectionString;

        public ReportExporter(string connectionString)
        {
            _connectionString = connectionString;
        }

        public void ExportToFile(string reportName, string outputPath)
        {
            // Manual resource management — Dispose never called if an exception occurs
            var connection = new SqlConnection(_connectionString);
            connection.Open();

            var command = new SqlCommand(
                "SELECT * FROM Reports WHERE Name = @name", connection);
            command.Parameters.AddWithValue("@name", reportName);

            var reader = command.ExecuteReader();
            var writer = new StreamWriter(outputPath, append: false, Encoding.UTF8);

            writer.WriteLine($"Report: {reportName}");
            writer.WriteLine(new string('-', 40));

            while (reader.Read())
            {
                writer.WriteLine(
                    $"{reader["Date"]:yyyy-MM-dd} | {reader["Value"]:N2}");
            }

            // These Dispose calls are never reached if an exception is thrown above
            reader.Dispose();
            command.Dispose();
            writer.Dispose();
            connection.Dispose();
        }

        public byte[] ExportToBytes(int reportId)
        {
            var memoryStream = new MemoryStream();
            var writer = new StreamWriter(memoryStream, Encoding.UTF8);

            var connection = new SqlConnection(_connectionString);
            connection.Open();

            var command = new SqlCommand(
                "SELECT * FROM ReportRows WHERE ReportId = @id ORDER BY RowIndex", connection);
            command.Parameters.AddWithValue("@id", reportId);

            var reader = command.ExecuteReader();
            while (reader.Read())
                writer.WriteLine(reader["Content"].ToString());

            writer.Flush();
            var result = memoryStream.ToArray();

            // Missing dispose calls on reader, command, connection
            writer.Dispose();
            memoryStream.Dispose();

            return result;
        }

        public void CopyReport(string sourcePath, string destinationPath)
        {
            var source = new FileStream(sourcePath, FileMode.Open, FileAccess.Read);
            var destination = new FileStream(destinationPath, FileMode.Create, FileAccess.Write);
            source.CopyTo(destination);
            source.Dispose();
            destination.Dispose(); // not reached if CopyTo throws
        }
    }
}
