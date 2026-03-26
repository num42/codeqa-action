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
            using var connection = new SqlConnection(_connectionString);
            connection.Open();

            using var command = new SqlCommand(
                "SELECT * FROM Reports WHERE Name = @name", connection);
            command.Parameters.AddWithValue("@name", reportName);

            using var reader = command.ExecuteReader();
            using var writer = new StreamWriter(outputPath, append: false, Encoding.UTF8);

            writer.WriteLine($"Report: {reportName}");
            writer.WriteLine(new string('-', 40));

            while (reader.Read())
            {
                writer.WriteLine(
                    $"{reader["Date"]:yyyy-MM-dd} | {reader["Value"]:N2}");
            }
        }

        public byte[] ExportToBytes(int reportId)
        {
            using var memoryStream = new MemoryStream();
            using var writer = new StreamWriter(memoryStream, Encoding.UTF8, leaveOpen: true);

            using var connection = new SqlConnection(_connectionString);
            connection.Open();

            using var command = new SqlCommand(
                "SELECT * FROM ReportRows WHERE ReportId = @id ORDER BY RowIndex", connection);
            command.Parameters.AddWithValue("@id", reportId);

            using var reader = command.ExecuteReader();
            while (reader.Read())
                writer.WriteLine(reader["Content"].ToString());

            writer.Flush();
            return memoryStream.ToArray();
        }

        public void CopyReport(string sourcePath, string destinationPath)
        {
            using var source = new FileStream(sourcePath, FileMode.Open, FileAccess.Read);
            using var destination = new FileStream(destinationPath, FileMode.Create, FileAccess.Write);
            source.CopyTo(destination);
        }
    }
}
