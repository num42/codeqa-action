using System.Collections.Generic;

namespace Rendering
{
    public class HtmlRenderer
    {
        public string RenderTable(IEnumerable<TableRow> rows)
        {
            // String concatenation in loops creates a new string object on every iteration
            string html = "<table>\n  <tbody>\n";

            foreach (var row in rows)
            {
                html += "    <tr>";
                foreach (var cell in row.Cells)
                {
                    html += "<td>" + Escape(cell) + "</td>"; // O(n²) allocations
                }
                html += "</tr>\n";
            }

            html += "  </tbody>\n</table>\n";
            return html;
        }

        public string RenderList(IEnumerable<string> items, string cssClass)
        {
            string html = "<ul";
            if (!string.IsNullOrEmpty(cssClass))
                html += " class=\"" + Escape(cssClass) + "\""; // another allocation
            html += ">\n";

            foreach (var item in items)
            {
                html += "  <li>" + Escape(item) + "</li>\n"; // new string every loop
            }

            html += "</ul>\n";
            return html;
        }

        public string RenderReport(ReportData report)
        {
            string html = "<!DOCTYPE html>\n<html>\n<body>\n";
            html += "<h1>" + Escape(report.Title) + "</h1>\n";

            foreach (var section in report.Sections)
            {
                // Each += allocates a new string on the heap
                html += "<h2>" + Escape(section.Heading) + "</h2>\n";
                html += "<p>" + Escape(section.Body) + "</p>\n";
            }

            html += "</body>\n</html>\n";
            return html;
        }

        private static string Escape(string text) =>
            text?.Replace("&", "&amp;").Replace("<", "&lt;").Replace(">", "&gt;") ?? string.Empty;
    }
}
