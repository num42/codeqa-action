defmodule CodeQA.LineReport.HtmlFormatter do
  @moduledoc "Generates self-contained HTML reports from per-line metric impact data."

  alias CodeQA.HealthReport.{Categories, Config}

  @spec generate(map(), String.t(), keyword()) :: :ok
  def generate(results, output_dir, opts \\ []) do
    ref = opts[:ref]
    report_dir = if ref, do: Path.join([output_dir, "reports", ref]), else: output_dir

    File.mkdir_p!(report_dir)

    config = Config.load(opts[:config])

    common_prefix = compute_common_prefix(Map.keys(results))
    directions_json = Jason.encode!(direction_map_serializable(config.categories))
    computed_json = Jason.encode!(computed_columns(config.categories))
    grade_scale_json = Jason.encode!(serialize_grade_scale(config.grade_scale))
    line_ranges = opts[:line_ranges] || []
    hide_lines = opts[:hide_lines] || false
    filter_json = Jason.encode!(%{ranges: line_ranges, hide: hide_lines})

    file_entries =
      results
      |> Enum.sort_by(fn {path, _} -> path end)
      |> Enum.map(fn {path, data} ->
        relative =
          case common_prefix do
            "" -> path
            prefix -> String.trim_leading(path, prefix)
          end
        html_path = relative <> ".html"
        {path, relative, html_path, data}
      end)

    Enum.each(file_entries, fn {_path, relative, html_path, data} ->
      dest = Path.join(report_dir, html_path)
      File.mkdir_p!(Path.dirname(dest))

      depth = length(Path.split(html_path)) - 1
      index_link = String.duplicate("../", depth) <> "index.html"

      data_json = Jason.encode!(data)
      meta_json = Jason.encode!(%{relativePath: relative, indexLink: index_link})

      html = file_page_html(data_json, directions_json, meta_json, computed_json, grade_scale_json, filter_json)
      File.write!(dest, html)
    end)

    if ref do
      write_manifest(output_dir, ref, file_entries)
      if opts[:max_reports], do: prune_reports(output_dir, opts[:max_reports])
    else
      index_data =
        Enum.map(file_entries, fn {_path, relative, html_path, data} ->
          %{relative: relative, htmlPath: html_path, lineCount: length(data.lines)}
        end)

      index_html = index_page_html(Jason.encode!(index_data))
      File.write!(Path.join(output_dir, "index.html"), index_html)
    end

    :ok
  end

  @doc "Returns computed column definitions derived from health report categories."
  @spec computed_columns() :: [map()]
  def computed_columns(categories \\ Categories.defaults()) do
    categories
    |> Enum.map(fn %{key: key, name: name, metrics: metrics} ->
      %{
        key: Atom.to_string(key),
        name: name,
        metrics:
          Enum.map(metrics, fn %{name: n, source: s, weight: w, good: g, thresholds: t} ->
            %{name: n, source: s, weight: w, good: Atom.to_string(g),
              thresholds: %{a: t.a, b: t.b, c: t.c, d: t.d}}
          end)
      }
    end)
  end

  defp serialize_grade_scale(scale) do
    Enum.map(scale, fn {min, letter} -> %{min: min, grade: letter} end)
  end

  @doc "Returns the good direction (:high or :low) for a metric."
  @spec metric_direction(String.t(), String.t()) :: :high | :low
  def metric_direction(source, metric_name) do
    direction_map()
    |> Map.get({source, metric_name}, :low)
  end

  @doc "Returns an RGBA color tuple for an impact value given its good direction."
  @spec impact_color(number(), :high | :low, number()) :: {non_neg_integer(), non_neg_integer(), non_neg_integer(), float()}
  def impact_color(value, _direction, _max_abs) when value == 0 or value == 0.0 do
    {0, 0, 0, 0.0}
  end

  def impact_color(value, direction, max_abs) when max_abs > 0 do
    is_good =
      case direction do
        :high -> value > 0
        :low -> value < 0
      end

    intensity = min(abs(value) / max_abs, 1.0)
    alpha = 0.1 + intensity * 0.4

    if is_good do
      {40, 167, 69, alpha}
    else
      {220, 53, 69, alpha}
    end
  end

  def impact_color(_value, _direction, _max_abs), do: {0, 0, 0, 0.0}

  # --- Manifest ---

  defp write_manifest(output_dir, ref, file_entries) do
    manifest_path = Path.join(output_dir, "manifest.json")

    existing =
      if File.exists?(manifest_path) do
        manifest_path |> File.read!() |> Jason.decode!()
      else
        %{"schemaVersion" => 1, "reports" => []}
      end

    entry = %{
      "ref" => ref,
      "generated_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "files" =>
        Enum.map(file_entries, fn {_path, relative, html_path, data} ->
          %{
            "path" => relative,
            "htmlPath" => html_path,
            "lineCount" => length(data.lines),
            "baseline" => data.baseline
          }
        end)
    }

    reports =
      existing["reports"]
      |> Enum.reject(fn r -> r["ref"] == ref end)
      |> Kernel.++([entry])

    File.mkdir_p!(output_dir)

    File.write!(
      manifest_path,
      Jason.encode!(%{"schemaVersion" => 1, "reports" => reports}, pretty: true)
    )
  end

  defp prune_reports(output_dir, max) when is_integer(max) and max > 0 do
    manifest_path = Path.join(output_dir, "manifest.json")
    manifest = manifest_path |> File.read!() |> Jason.decode!()
    reports = manifest["reports"]

    if length(reports) > max do
      sorted = Enum.sort_by(reports, & &1["generated_at"])
      {to_remove, to_keep} = Enum.split(sorted, length(sorted) - max)

      Enum.each(to_remove, fn report ->
        report_dir = Path.join([output_dir, "reports", report["ref"]])
        File.rm_rf!(report_dir)
      end)

      File.write!(manifest_path, Jason.encode!(%{"schemaVersion" => 1, "reports" => to_keep}, pretty: true))
    end
  end

  defp prune_reports(_output_dir, _max), do: :ok

  # --- HTML Templates ---

  defp file_page_html(data_json, directions_json, meta_json, computed_json, grade_scale_json, filter_json) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeQA Line Report</title>
    <style>
    #{file_page_css()}
    </style>
    </head>
    <body>
    <nav><a id="back-link" href="#">&larr; Index</a></nav>
    <h1 id="title"></h1>
    <details><summary>Baseline Metrics</summary><div id="baseline" class="baseline-grid"></div></details>
    <details id="weights-details"><summary>Weights</summary><div id="weights-panel" class="weights-panel"></div></details>
    <details id="filter-details"><summary>Line Filter</summary><div id="filter-panel" class="filter-panel"></div></details>
    <div class="source-container">
      <table><thead id="thead"></thead><tbody id="tbody"></tbody></table>
    </div>
    <footer>Generated by CodeQA</footer>
    <script>
    window.__DATA__ = #{data_json};
    window.__DIRECTIONS__ = #{directions_json};
    window.__META__ = #{meta_json};
    window.__COMPUTED__ = #{computed_json};
    window.__GRADE_SCALE__ = #{grade_scale_json};
    window.__FILTER__ = #{filter_json};
    </script>
    <script>
    #{file_page_js()}
    </script>
    </body>
    </html>
    """
  end

  defp file_page_css do
    ~S"""
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, monospace; background: #1e1e2e; color: #cdd6f4; padding: 20px; }
    nav { margin-bottom: 16px; }
    nav a { color: #89b4fa; text-decoration: none; }
    h1 { font-size: 1.2em; margin-bottom: 12px; color: #cdd6f4; }
    details { margin-bottom: 16px; background: #313244; padding: 12px; border-radius: 6px; }
    summary { cursor: pointer; font-weight: bold; color: #a6adc8; }
    .baseline-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 8px; margin-top: 8px; }
    .baseline-item { font-size: 0.85em; color: #bac2de; }
    .baseline-item .key { color: #a6adc8; }
    .baseline-item .val { color: #f5c2e7; }
    .source-container { overflow-x: auto; border: 1px solid #45475a; border-radius: 6px; }
    table { border-collapse: separate; border-spacing: 0; table-layout: fixed; }
    thead th { padding: 6px 8px; font-size: 0.75em; font-weight: 600; color: #a6adc8; border-bottom: 2px solid #45475a; white-space: nowrap; background: #313244; position: sticky; top: 0; z-index: 2; overflow: hidden; text-overflow: ellipsis; position: relative; }
    thead th .resize-handle { position: absolute; right: 0; top: 0; bottom: 0; width: 5px; cursor: col-resize; background: transparent; }
    thead th .resize-handle:hover, thead th .resize-handle.active { background: #89b4fa; }
    .line-num-header, .line-num { text-align: right; width: 3.5em; position: sticky; left: 0; z-index: 3; background: #1e1e2e; }
    .code-header, .code { text-align: left; width: 30vw; min-width: 200px; max-width: 30vw; position: sticky; left: 3.5em; z-index: 3; background: #1e1e2e; }
    thead .line-num-header, thead .code-header { z-index: 4; background: #313244; }
    .metric-header { text-align: right; max-width: 5em; overflow: hidden; text-overflow: ellipsis; }
    tbody tr { border-bottom: 1px solid #31324422; }
    tbody tr:hover { background: rgba(137,180,250,0.06); }
    tbody tr:hover .line-num, tbody tr:hover .code { background: rgba(49,50,68,0.95); }
    .line-num { padding: 0 8px; color: #585b70; white-space: nowrap; user-select: none; -webkit-user-select: none; -moz-user-select: none; border-right: 1px solid #45475a; }
    .code { padding: 0 12px; border-right: 1px solid #45475a; cursor: pointer; }
    .code code { white-space: pre; overflow: hidden; text-overflow: ellipsis; display: block; font-family: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace; font-size: 0.9em; line-height: 1.6; }
    .code.expanded code { white-space: pre-wrap; word-break: break-all; overflow-wrap: break-word; overflow: visible; }
    .metric-cell { text-align: right; padding: 0 6px; font-size: 0.8em; font-family: 'SF Mono', monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #bac2de; cursor: pointer; }
    .metric-cell.expanded { white-space: pre-wrap; overflow: visible; }
    .weights-panel { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; margin-top: 8px; }
    .weight-group { background: #1e1e2e; border: 1px solid #45475a; border-radius: 4px; padding: 8px; }
    .weight-group-title { font-size: 0.85em; font-weight: 600; color: #cba6f7; margin-bottom: 6px; }
    .weight-row { display: flex; align-items: center; gap: 6px; margin-bottom: 4px; font-size: 0.8em; }
    .weight-row label { flex: 1; color: #a6adc8; }
    .weight-input { width: 60px; background: #313244; border: 1px solid #45475a; border-radius: 3px; color: #cdd6f4; padding: 2px 4px; font-size: 0.85em; text-align: right; }
    .computed-header { text-align: right; min-width: 8em; background: #2a2a3e !important; border-left: 2px solid #cba6f7; }
    .computed-cell { text-align: right; padding: 0 6px; font-size: 0.8em; font-family: 'SF Mono', monospace; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: #cdd6f4; cursor: pointer; border-left: 2px solid #cba6f733; }
    .computed-cell.expanded { white-space: pre-wrap; overflow: visible; }
    .grade-header { text-align: center; min-width: 2.5em; background: #2a2a3e !important; border-left: 2px solid #cba6f7; }
    .grade-cell { text-align: center; padding: 0 4px; font-size: 0.85em; font-weight: 700; font-family: 'SF Mono', monospace; white-space: nowrap; border-left: 2px solid #cba6f733; }
    .grade-A { color: #a6e3a1; } .grade-B { color: #94e2d5; } .grade-C { color: #f9e2af; } .grade-D { color: #fab387; } .grade-F { color: #f38ba8; }
    .filter-panel { margin-top: 8px; }
    .filter-controls { display: flex; align-items: center; gap: 8px; margin-bottom: 8px; flex-wrap: wrap; }
    .filter-controls label { color: #a6adc8; font-size: 0.85em; }
    .filter-controls select, .filter-controls input { background: #313244; border: 1px solid #45475a; border-radius: 3px; color: #cdd6f4; padding: 3px 6px; font-size: 0.85em; }
    .filter-controls input[type="number"] { width: 70px; text-align: right; }
    .filter-controls button { background: #45475a; border: none; border-radius: 3px; color: #cdd6f4; padding: 4px 10px; cursor: pointer; font-size: 0.85em; }
    .filter-controls button:hover { background: #585b70; }
    .filter-tags { display: flex; flex-wrap: wrap; gap: 6px; }
    .filter-tag { display: inline-flex; align-items: center; gap: 4px; background: #313244; border: 1px solid #45475a; border-radius: 4px; padding: 2px 8px; font-size: 0.8em; color: #cdd6f4; }
    .filter-tag .remove-tag { cursor: pointer; color: #f38ba8; font-weight: bold; margin-left: 2px; }
    .filter-tag .remove-tag:hover { color: #eba0ac; }
    .metric-cell.highlight { box-shadow: inset 0 0 0 2px #cba6f7; border-radius: 2px; }
    thead th { cursor: pointer; }
    thead th .sort-arrow { font-size: 0.7em; margin-left: 2px; color: #585b70; }
    thead th .sort-arrow.active { color: #cba6f7; }
    footer { margin-top: 24px; text-align: center; color: #585b70; font-size: 0.8em; }
    """
  end

  defp file_page_js do
    ~S"""
    (function() {
      const data = window.__DATA__;
      const dirs = window.__DIRECTIONS__;
      const meta = window.__META__;
      const computedDefs = window.__COMPUTED__;
      const gradeScale = window.__GRADE_SCALE__;
      const filterInit = window.__FILTER__;

      // Line filter state
      var filterRanges = (filterInit.ranges || []).map(function(r) { return [r[0], r[1]]; });
      var filterHide = filterInit.hide || false;

      function lineMatchesFilter(lineNum) {
        if (filterRanges.length === 0) return true;
        var inRange = filterRanges.some(function(r) { return lineNum >= r[0] && lineNum <= r[1]; });
        return filterHide ? !inRange : inRange;
      }

      document.title = meta.relativePath + ' — CodeQA Line Report';
      document.getElementById('title').textContent = meta.relativePath;
      document.getElementById('back-link').href = meta.indexLink;

      // Baseline
      const baselineEl = document.getElementById('baseline');
      for (const [source, metrics] of Object.entries(data.baseline)) {
        for (const [key, val] of Object.entries(metrics)) {
          const div = document.createElement('div');
          div.className = 'baseline-item';
          const formatted = typeof val === 'number' ? (Number.isInteger(val) ? val : val.toFixed(3)) : val;
          div.innerHTML = '<span class="key">' + source + '.' + key + ':</span> <span class="val">' + formatted + '</span>';
          baselineEl.appendChild(div);
        }
      }

      // Weights panel
      const weightsPanel = document.getElementById('weights-panel');
      const weights = {};
      for (const cat of computedDefs) {
        weights[cat.key] = {};
        const group = document.createElement('div');
        group.className = 'weight-group';
        const title = document.createElement('div');
        title.className = 'weight-group-title';
        title.textContent = cat.name;
        group.appendChild(title);
        for (const m of cat.metrics) {
          weights[cat.key][m.source + '.' + m.name] = m.weight;
          const row = document.createElement('div');
          row.className = 'weight-row';
          const lbl = document.createElement('label');
          lbl.textContent = m.source + '.' + m.name;
          row.appendChild(lbl);
          const inp = document.createElement('input');
          inp.type = 'number';
          inp.step = '0.05';
          inp.min = '0';
          inp.value = m.weight;
          inp.className = 'weight-input';
          inp.dataset.cat = cat.key;
          inp.dataset.metric = m.source + '.' + m.name;
          inp.addEventListener('input', function() {
            weights[this.dataset.cat][this.dataset.metric] = parseFloat(this.value) || 0;
            recomputeAll();
          });
          row.appendChild(inp);
          group.appendChild(row);
        }
        weightsPanel.appendChild(group);
      }

      // Filter panel UI
      var filterPanel = document.getElementById('filter-panel');
      var filterControls = document.createElement('div');
      filterControls.className = 'filter-controls';

      var modeLabel = document.createElement('label');
      modeLabel.textContent = 'Mode:';
      filterControls.appendChild(modeLabel);
      var modeSelect = document.createElement('select');
      var optShow = document.createElement('option');
      optShow.value = 'show'; optShow.textContent = 'Show only';
      var optHide = document.createElement('option');
      optHide.value = 'hide'; optHide.textContent = 'Hide';
      modeSelect.appendChild(optShow);
      modeSelect.appendChild(optHide);
      modeSelect.value = filterHide ? 'hide' : 'show';
      modeSelect.addEventListener('change', function() {
        filterHide = this.value === 'hide';
        applyFilter();
      });
      filterControls.appendChild(modeSelect);

      var fromLabel = document.createElement('label');
      fromLabel.textContent = 'From:';
      filterControls.appendChild(fromLabel);
      var fromInput = document.createElement('input');
      fromInput.type = 'number'; fromInput.min = '1'; fromInput.placeholder = '1';
      filterControls.appendChild(fromInput);

      var toLabel = document.createElement('label');
      toLabel.textContent = 'To:';
      filterControls.appendChild(toLabel);
      var toInput = document.createElement('input');
      toInput.type = 'number'; toInput.min = '1'; toInput.placeholder = '99';
      filterControls.appendChild(toInput);

      var addBtn = document.createElement('button');
      addBtn.textContent = 'Add Range';
      addBtn.addEventListener('click', function() {
        var from = parseInt(fromInput.value);
        var to = parseInt(toInput.value);
        if (isNaN(from)) return;
        if (isNaN(to)) to = from;
        if (from > to) { var tmp = from; from = to; to = tmp; }
        filterRanges.push([from, to]);
        fromInput.value = ''; toInput.value = '';
        renderTags();
        applyFilter();
      });
      filterControls.appendChild(addBtn);

      var clearBtn = document.createElement('button');
      clearBtn.textContent = 'Clear All';
      clearBtn.addEventListener('click', function() {
        filterRanges = [];
        renderTags();
        applyFilter();
      });
      filterControls.appendChild(clearBtn);

      filterPanel.appendChild(filterControls);

      var tagsContainer = document.createElement('div');
      tagsContainer.className = 'filter-tags';
      filterPanel.appendChild(tagsContainer);

      function renderTags() {
        tagsContainer.innerHTML = '';
        filterRanges.forEach(function(r, i) {
          var tag = document.createElement('span');
          tag.className = 'filter-tag';
          tag.textContent = r[0] === r[1] ? 'L' + r[0] : 'L' + r[0] + '-' + r[1];
          var x = document.createElement('span');
          x.className = 'remove-tag';
          x.textContent = '\u00D7';
          x.addEventListener('click', function() {
            filterRanges.splice(i, 1);
            renderTags();
            applyFilter();
          });
          tag.appendChild(x);
          tagsContainer.appendChild(tag);
        });
      }
      renderTags();

      function applyFilter() {
        var rows = tbody.rows;
        for (var r = 0; r < rows.length; r++) {
          var lineNum = parseInt(rows[r].cells[0].textContent);
          rows[r].style.display = lineMatchesFilter(lineNum) ? '' : 'none';
        }
      }

      function computeValue(impact, catKey) {
        const cat = computedDefs.find(function(c) { return c.key === catKey; });
        if (!cat) return 0;
        var sum = 0;
        var wSum = 0;
        for (const m of cat.metrics) {
          var w = weights[catKey][m.source + '.' + m.name] || 0;
          var val = (impact[m.source] || {})[m.name] || 0;
          sum += val * w;
          wSum += w;
        }
        return wSum === 0 ? 0 : sum / wSum;
      }

      // Rank-based grading: score each line's impact by percentile
      var computedValues = {};
      function buildRanks() {
        for (const cat of computedDefs) {
          var vals = data.lines.map(function(l) { return computeValue(l.impact, cat.key); });
          vals.sort(function(a, b) { return a - b; });
          computedValues[cat.key] = vals;
        }
      }
      buildRanks();

      function gradeImpact(value, catKey) {
        var sorted = computedValues[catKey];
        if (!sorted || sorted.length === 0) return {score: 50, grade: 'C'};
        // Lower impact is better (less harmful to remove)
        // Rank: what fraction of lines have higher (worse) impact
        var rank = 0;
        for (var i = 0; i < sorted.length; i++) {
          if (sorted[i] <= value) rank = i;
        }
        // score 0-100: 100 = best (lowest impact), 0 = worst (highest impact)
        var score = Math.round((1 - rank / Math.max(1, sorted.length - 1)) * 100);
        var grade = 'F';
        for (const g of gradeScale) {
          if (score >= g.min) { grade = g.grade; break; }
        }
        return {score: score, grade: grade};
      }

      function gradeClass(letter) {
        if (letter.startsWith('A')) return 'grade-A';
        if (letter.startsWith('B')) return 'grade-B';
        if (letter.startsWith('C')) return 'grade-C';
        if (letter.startsWith('D')) return 'grade-D';
        return 'grade-F';
      }

      // Build category -> contributing metric keys map
      var catMetricKeys = {};
      for (const cat of computedDefs) {
        catMetricKeys[cat.key] = cat.metrics.map(function(m) { return m.source + '|' + m.name; });
      }

      function toggleContributors(e) {
        e.stopPropagation();
        var catKey = this.dataset.cat;
        var row = this.closest('tr');
        var keys = catMetricKeys[catKey] || [];
        var cells = row.querySelectorAll('.metric-cell');
        var anyActive = false;
        cells.forEach(function(c) {
          var k = c.dataset.source + '|' + c.dataset.metric;
          if (keys.indexOf(k) !== -1 && c.classList.contains('highlight')) anyActive = true;
        });
        // Clear all highlights in this row first
        cells.forEach(function(c) { c.classList.remove('highlight'); });
        // If none were active, highlight the contributors
        if (!anyActive) {
          cells.forEach(function(c) {
            var k = c.dataset.source + '|' + c.dataset.metric;
            if (keys.indexOf(k) !== -1) c.classList.add('highlight');
          });
        }
      }

      // Collect metric columns from first line
      const columns = [];
      if (data.lines.length > 0) {
        const impact = data.lines[0].impact;
        for (const source of Object.keys(impact).sort()) {
          for (const key of Object.keys(impact[source]).sort()) {
            columns.push([source, key]);
          }
        }
      }

      // Compute max abs per column
      const maxAbs = {};
      for (const col of columns) {
        const k = col[0] + '.' + col[1];
        let mx = 0;
        for (const line of data.lines) {
          const v = (line.impact[col[0]] || {})[col[1]] || 0;
          mx = Math.max(mx, Math.abs(v));
        }
        maxAbs[k] = mx || 1;
      }

      // Compute max abs per computed column
      const computedMaxAbs = {};
      for (const cat of computedDefs) {
        let mx = 0;
        for (const line of data.lines) {
          mx = Math.max(mx, Math.abs(computeValue(line.impact, cat.key)));
        }
        computedMaxAbs[cat.key] = mx || 1;
      }

      function computedColor(value, maxAbsVal) {
        if (value === 0) return 'transparent';
        const intensity = Math.min(Math.abs(value) / maxAbsVal, 1.0);
        const alpha = (0.1 + intensity * 0.4).toFixed(3);
        return value < 0 ? 'rgba(59,130,246,' + alpha + ')' : 'rgba(234,179,8,' + alpha + ')';
      }

      function impactColor(value, direction, maxAbsVal) {
        if (value === 0) return 'transparent';
        const isGood = direction === 'high' ? value > 0 : value < 0;
        const intensity = Math.min(Math.abs(value) / maxAbsVal, 1.0);
        const alpha = (0.1 + intensity * 0.4).toFixed(3);
        return isGood ? 'rgba(40,167,69,' + alpha + ')' : 'rgba(220,53,69,' + alpha + ')';
      }

      function getDirection(source, key) {
        return dirs[source + '.' + key] || 'low';
      }

      function formatVal(v) {
        var abs = Math.abs(v);
        if (abs === 0) return '+0.00';
        var s = (abs > 0 && abs < 0.005) || abs >= 1000 ? v.toExponential(2) : v.toFixed(2);
        return (v >= 0 ? '+' : '') + s;
      }

      function toggleExpand() { this.classList.toggle('expanded'); }

      // Header
      const thead = document.getElementById('thead');
      const headerRow = document.createElement('tr');
      const numTh = document.createElement('th');
      numTh.className = 'line-num-header';
      numTh.textContent = '#';
      headerRow.appendChild(numTh);
      const codeTh = document.createElement('th');
      codeTh.className = 'code-header';
      codeTh.textContent = 'Code';
      headerRow.appendChild(codeTh);
      for (const cat of computedDefs) {
        const gth = document.createElement('th');
        gth.className = 'grade-header';
        gth.title = cat.name + ' Grade';
        gth.textContent = '';
        headerRow.appendChild(gth);
        const th = document.createElement('th');
        th.className = 'computed-header';
        th.title = cat.name + ' (computed)';
        th.textContent = cat.name;
        headerRow.appendChild(th);
      }
      for (const [source, key] of columns) {
        const th = document.createElement('th');
        th.className = 'metric-header';
        th.title = source + '.' + key;
        th.textContent = source.slice(0, 4) + '.' + key.slice(0, 6);
        headerRow.appendChild(th);
      }
      thead.appendChild(headerRow);

      // Column resize handles
      const allThs = headerRow.querySelectorAll('th');
      allThs.forEach(function(th) {
        const handle = document.createElement('div');
        handle.className = 'resize-handle';
        th.appendChild(handle);

        handle.addEventListener('mousedown', function(e) {
          e.preventDefault();
          const startX = e.clientX;
          const startW = th.offsetWidth;
          handle.classList.add('active');
          document.body.style.cursor = 'col-resize';
          document.body.style.userSelect = 'none';

          function onMove(ev) {
            const w = Math.max(30, startW + ev.clientX - startX);
            th.style.width = w + 'px';
            th.style.minWidth = w + 'px';
            th.style.maxWidth = w + 'px';
            // Apply same width to all cells in this column
            const idx = Array.from(allThs).indexOf(th);
            const rows = document.getElementById('tbody').rows;
            for (let r = 0; r < rows.length; r++) {
              const cell = rows[r].cells[idx];
              if (cell) {
                cell.style.width = w + 'px';
                cell.style.minWidth = w + 'px';
                cell.style.maxWidth = w + 'px';
              }
            }
          }
          function onUp() {
            handle.classList.remove('active');
            document.body.style.cursor = '';
            document.body.style.userSelect = '';
            document.removeEventListener('mousemove', onMove);
            document.removeEventListener('mouseup', onUp);
          }
          document.addEventListener('mousemove', onMove);
          document.addEventListener('mouseup', onUp);
        });
      });

      // Rows
      const tbody = document.getElementById('tbody');
      const frag = document.createDocumentFragment();
      for (const line of data.lines) {
        const tr = document.createElement('tr');

        const numTd = document.createElement('td');
        numTd.className = 'line-num';
        numTd.textContent = line.line_number;
        tr.appendChild(numTd);

        const codeTd = document.createElement('td');
        codeTd.className = 'code';
        const codeEl = document.createElement('code');
        codeEl.textContent = line.content;
        codeTd.appendChild(codeEl);
        codeTd.onclick = toggleExpand;
        tr.appendChild(codeTd);

        for (const cat of computedDefs) {
          const cv = computeValue(line.impact, cat.key);
          var g = gradeImpact(cv, cat.key);
          const gtd = document.createElement('td');
          gtd.className = 'grade-cell ' + gradeClass(g.grade);
          gtd.dataset.cat = cat.key;
          gtd.title = cat.name + ': ' + g.grade + ' (' + g.score + ')';
          gtd.textContent = g.grade;
          tr.appendChild(gtd);

          const td = document.createElement('td');
          td.className = 'computed-cell';
          td.dataset.cat = cat.key;
          td.style.background = computedColor(cv, computedMaxAbs[cat.key]);
          td.title = cat.name + ': ' + (cv >= 0 ? '+' : '') + cv.toFixed(4);
          td.textContent = formatVal(cv);
          td.onclick = toggleContributors;
          tr.appendChild(td);
        }

        for (const [source, key] of columns) {
          const val = (line.impact[source] || {})[key] || 0;
          const k = source + '.' + key;
          const dir = getDirection(source, key);
          const bg = impactColor(val, dir, maxAbs[k]);

          const td = document.createElement('td');
          td.className = 'metric-cell';
          td.dataset.source = source;
          td.dataset.metric = key;
          td.style.background = bg;
          td.title = source + '.' + key + ': ' + (val >= 0 ? '+' : '') + val.toFixed(4);
          td.textContent = formatVal(val);
          td.onclick = toggleExpand;
          tr.appendChild(td);
        }

        frag.appendChild(tr);
      }
      tbody.appendChild(frag);
      applyFilter();

      function recomputeAll() {
        buildRanks();
        // Recompute max abs for color scaling
        for (const cat of computedDefs) {
          let mx = 0;
          for (const line of data.lines) {
            mx = Math.max(mx, Math.abs(computeValue(line.impact, cat.key)));
          }
          computedMaxAbs[cat.key] = mx || 1;
        }
        const rows = tbody.rows;
        for (var r = 0; r < rows.length; r++) {
          const line = data.lines[r];
          const gradeCells = rows[r].querySelectorAll('.grade-cell');
          const compCells = rows[r].querySelectorAll('.computed-cell');
          var ci = 0;
          for (const cat of computedDefs) {
            const cv = computeValue(line.impact, cat.key);
            var g = gradeImpact(cv, cat.key);
            gradeCells[ci].textContent = g.grade;
            gradeCells[ci].className = 'grade-cell ' + gradeClass(g.grade);
            gradeCells[ci].title = cat.name + ': ' + g.grade + ' (' + g.score + ')';
            compCells[ci].textContent = formatVal(cv);
            compCells[ci].title = cat.name + ': ' + (cv >= 0 ? '+' : '') + cv.toFixed(4);
            compCells[ci].style.background = computedColor(cv, computedMaxAbs[cat.key]);
            ci++;
          }
        }
      }
      // Sorting
      var sortCol = -1;
      var sortAsc = true;
      var lineIndices = data.lines.map(function(_, i) { return i; });

      // Build column value extractors: one per th
      // Columns: #, Code, [grade, computed] * N, [metric] * N
      var colCount = 2 + computedDefs.length * 2 + columns.length;
      function getCellValue(lineIdx, colIdx) {
        var line = data.lines[lineIdx];
        if (colIdx === 0) return line.line_number;
        if (colIdx === 1) return line.content;
        var ci = 2;
        for (var c = 0; c < computedDefs.length; c++) {
          if (colIdx === ci) { // grade column — sort by score
            var cv = computeValue(line.impact, computedDefs[c].key);
            return gradeImpact(cv, computedDefs[c].key).score;
          }
          ci++;
          if (colIdx === ci) return computeValue(line.impact, computedDefs[c].key); // computed value
          ci++;
        }
        var mi = colIdx - ci;
        if (mi >= 0 && mi < columns.length) {
          var col = columns[mi];
          return (line.impact[col[0]] || {})[col[1]] || 0;
        }
        return 0;
      }

      function rebuildTable() {
        while (tbody.firstChild) tbody.removeChild(tbody.firstChild);
        var frag2 = document.createDocumentFragment();
        for (var idx of lineIndices) {
          var line = data.lines[idx];
          var tr = document.createElement('tr');

          var numTd = document.createElement('td');
          numTd.className = 'line-num';
          numTd.textContent = line.line_number;
          tr.appendChild(numTd);

          var codeTd = document.createElement('td');
          codeTd.className = 'code';
          var codeEl = document.createElement('code');
          codeEl.textContent = line.content;
          codeTd.appendChild(codeEl);
          codeTd.onclick = toggleExpand;
          tr.appendChild(codeTd);

          for (const cat of computedDefs) {
            var cv = computeValue(line.impact, cat.key);
            var g = gradeImpact(cv, cat.key);
            var gtd = document.createElement('td');
            gtd.className = 'grade-cell ' + gradeClass(g.grade);
            gtd.dataset.cat = cat.key;
            gtd.title = cat.name + ': ' + g.grade + ' (' + g.score + ')';
            gtd.textContent = g.grade;
            tr.appendChild(gtd);

            var td = document.createElement('td');
            td.className = 'computed-cell';
            td.dataset.cat = cat.key;
            td.style.background = computedColor(cv, computedMaxAbs[cat.key]);
            td.title = cat.name + ': ' + (cv >= 0 ? '+' : '') + cv.toFixed(4);
            td.textContent = formatVal(cv);
            td.onclick = toggleContributors;
            tr.appendChild(td);
          }

          for (const [source, key] of columns) {
            var val = (line.impact[source] || {})[key] || 0;
            var k = source + '.' + key;
            var dir = getDirection(source, key);
            var bg = impactColor(val, dir, maxAbs[k]);
            var td = document.createElement('td');
            td.className = 'metric-cell';
            td.dataset.source = source;
            td.dataset.metric = key;
            td.style.background = bg;
            td.title = source + '.' + key + ': ' + (val >= 0 ? '+' : '') + val.toFixed(4);
            td.textContent = formatVal(val);
            td.onclick = toggleExpand;
            tr.appendChild(td);
          }
          frag2.appendChild(tr);
        }
        tbody.appendChild(frag2);
        applyFilter();
      }

      function sortByColumn(colIdx) {
        if (sortCol === colIdx) {
          sortAsc = !sortAsc;
        } else {
          sortCol = colIdx;
          sortAsc = true;
        }
        lineIndices.sort(function(a, b) {
          var va = getCellValue(a, colIdx);
          var vb = getCellValue(b, colIdx);
          if (typeof va === 'string') {
            var cmp = va.localeCompare(vb);
            return sortAsc ? cmp : -cmp;
          }
          return sortAsc ? va - vb : vb - va;
        });
        rebuildTable();
        // Update sort arrows
        var arrows = headerRow.querySelectorAll('.sort-arrow');
        arrows.forEach(function(a, i) {
          a.classList.toggle('active', i === colIdx);
          a.textContent = i === colIdx ? (sortAsc ? ' \u25B2' : ' \u25BC') : ' \u25B2';
        });
      }

      // Add sort click handlers and arrows to all headers
      var allHeaders = headerRow.querySelectorAll('th');
      allHeaders.forEach(function(th, i) {
        var arrow = document.createElement('span');
        arrow.className = 'sort-arrow';
        arrow.textContent = ' \u25B2';
        th.appendChild(arrow);
        th.addEventListener('click', function(e) {
          if (e.target.classList.contains('resize-handle')) return;
          sortByColumn(i);
        });
      });
    })();
    """
  end

  defp index_page_html(index_data_json) do
    """
    <!DOCTYPE html>
    <html lang="en">
    <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CodeQA Line Report</title>
    <style>
    #{index_css()}
    </style>
    </head>
    <body>
    <h1>CodeQA Line Report</h1>
    <p id="summary" class="summary"></p>
    <table>
    <thead><tr><th>File</th><th>Lines</th></tr></thead>
    <tbody id="tbody"></tbody>
    </table>
    <footer>Generated by CodeQA</footer>
    <script>
    window.__INDEX__ = #{index_data_json};
    </script>
    <script>
    #{index_js()}
    </script>
    </body>
    </html>
    """
  end

  defp index_css do
    ~S"""
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #1e1e2e; color: #cdd6f4; padding: 20px; max-width: 960px; margin: 0 auto; }
    h1 { margin-bottom: 8px; }
    .summary { color: #a6adc8; margin-bottom: 16px; }
    table { width: 100%; border-collapse: collapse; }
    th, td { text-align: left; padding: 8px 12px; border-bottom: 1px solid #45475a; }
    th { color: #a6adc8; font-weight: 600; }
    td a { color: #89b4fa; text-decoration: none; }
    td a:hover { text-decoration: underline; }
    footer { margin-top: 24px; text-align: center; color: #585b70; font-size: 0.8em; }
    """
  end

  defp index_js do
    ~S"""
    (function() {
      const files = window.__INDEX__;
      const totalLines = files.reduce((s, f) => s + f.lineCount, 0);
      document.getElementById('summary').textContent = files.length + ' files, ' + totalLines + ' lines analyzed';

      const tbody = document.getElementById('tbody');
      for (const f of files) {
        const tr = document.createElement('tr');
        tr.innerHTML = '<td><a href="' + f.htmlPath + '">' + f.relative + '</a></td><td>' + f.lineCount + '</td>';
        tbody.appendChild(tr);
      }
    })();
    """
  end

  # --- Path helpers ---

  defp compute_common_prefix([]), do: ""

  defp compute_common_prefix([single]) do
    parent = Path.dirname(Path.dirname(single))
    if parent == "." or parent == "", do: "", else: parent <> "/"
  end

  defp compute_common_prefix(paths) do
    dirs = Enum.map(paths, fn p -> Path.dirname(p) |> Path.split() end)
    min_len = dirs |> Enum.map(&length/1) |> Enum.min()

    common =
      Enum.reduce_while(0..(min_len - 1), [], fn i, acc ->
        segment = hd(dirs) |> Enum.at(i)

        if Enum.all?(dirs, fn s -> Enum.at(s, i) == segment end) do
          {:cont, acc ++ [segment]}
        else
          {:halt, acc}
        end
      end)

    common =
      cond do
        length(common) > 2 -> Enum.drop(common, -1)
        length(common) == 2 and hd(common) != "/" -> Enum.drop(common, -1)
        true -> common
      end

    case common do
      [] -> ""
      ["/"] -> "/"
      parts -> Path.join(parts) <> "/"
    end
  end

  # --- Metric direction ---

  defp direction_map(categories \\ Categories.defaults()) do
    categories
    |> Enum.flat_map(fn %{metrics: metrics} ->
      Enum.map(metrics, fn %{name: name, source: source, good: good} ->
        {{source, name}, good}
      end)
    end)
    |> Map.new()
  end

  defp direction_map_serializable(categories) do
    direction_map(categories)
    |> Map.new(fn {{source, name}, good} ->
      {"#{source}.#{name}", Atom.to_string(good)}
    end)
  end
end
