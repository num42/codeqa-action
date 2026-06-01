using System.Collections.Generic;
using System.Text;

namespace Rendering
{
    public class HtmlRenderer
    {
        public string RenderTable(IEnumerable<TableRow> rows)
        {
            var sb = new StringBuilder();
            sb.AppendLine("<table>");
            sb.AppendLine("  <tbody>");

            foreach (var row in rows)
            {
                sb.Append("    <tr>");
                foreach (var cell in row.Cells)
                {
                    sb.Append("<td>")
                      .Append(Escape(cell))
                      .Append("</td>");
                }
                sb.AppendLine("</tr>");
            }

            sb.AppendLine("  </tbody>");
            sb.AppendLine("</table>");
            return sb.ToString();
        }

        public string RenderList(IEnumerable<string> items, string cssClass)
        {
            var sb = new StringBuilder();
            sb.Append("<ul");
            if (!string.IsNullOrEmpty(cssClass))
                sb.Append(" class=\"").Append(Escape(cssClass)).Append('"');
            sb.AppendLine(">");

            foreach (var item in items)
            {
                sb.Append("  <li>").Append(Escape(item)).AppendLine("</li>");
            }

            sb.AppendLine("</ul>");
            return sb.ToString();
        }

        public string RenderReport(ReportData report)
        {
            var sb = new StringBuilder(capacity: 4096);
            sb.AppendLine("<!DOCTYPE html>")
              .AppendLine("<html>")
              .AppendLine("<body>");

            sb.Append("<h1>").Append(Escape(report.Title)).AppendLine("</h1>");

            foreach (var section in report.Sections)
            {
                sb.Append("<h2>").Append(Escape(section.Heading)).AppendLine("</h2>");
                sb.Append("<p>").Append(Escape(section.Body)).AppendLine("</p>");
            }

            sb.AppendLine("</body>")
              .AppendLine("</html>");

            return sb.ToString();
        }

        private static string Escape(string text) =>
            text?.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;") ?? string.Empty;
    }
}
