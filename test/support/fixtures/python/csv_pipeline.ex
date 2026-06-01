defmodule Test.Fixtures.Python.CsvPipeline do
  @moduledoc false
  use Test.LanguageFixture, language: "python csv_pipeline"

  @code ~S'''
  from dataclasses import dataclass, field
  from typing import Iterator, Protocol


  @dataclass
  class CsvRow:
      """Represents one row of parsed CSV data."""

      fields: dict
      line_number: int

      def get(self, key: str, default=None):
          """Returns the value for key or default."""
          return self.fields.get(key, default)

      def keys(self) -> list:
          """Returns all field names."""
          return list(self.fields.keys())


  class RowTransformer(Protocol):
      """Protocol for CSV row transformation steps."""

      def transform(self, row: CsvRow) -> CsvRow:
          """Transforms a single row."""
          ...


  @dataclass
  class ColumnRenamer:
      """Renames columns according to a mapping."""

      mapping: dict = field(default_factory=dict)

      def transform(self, row: CsvRow) -> CsvRow:
          """Applies column rename mapping to a row."""
          new_fields = {self.mapping.get(k, k): v for k, v in row.fields.items()}
          return CsvRow(fields=new_fields, line_number=row.line_number)


  @dataclass
  class TypeCoercer:
      """Coerces column values to specified types."""

      types: dict = field(default_factory=dict)

      def transform(self, row: CsvRow) -> CsvRow:
          """Coerces field values using the types mapping."""
          coerced = {}
          for key, value in row.fields.items():
              target_type = self.types.get(key)
              if target_type is not None:
                  try:
                      coerced[key] = target_type(value)
                  except (ValueError, TypeError):
                      coerced[key] = value
              else:
                  coerced[key] = value
          return CsvRow(fields=coerced, line_number=row.line_number)


  class CsvPipeline:
      """Streaming CSV pipeline with pluggable transformation steps."""

      def __init__(self, path: str):
          """Initialises the pipeline for the given CSV file path."""
          self._path = path
          self._steps: list = []

      def add_step(self, step: RowTransformer) -> "CsvPipeline":
          """Adds a transformation step and returns self for chaining."""
          self._steps.append(step)
          return self

      def run(self) -> Iterator[CsvRow]:
          """Yields processed rows from the CSV file."""
          with open(self._path, "r", newline="") as fh:
              import csv
              reader = csv.DictReader(fh)
              for line_number, raw in enumerate(reader, start=1):
                  row = CsvRow(fields=dict(raw), line_number=line_number)
                  for step in self._steps:
                      row = step.transform(row)
                  yield row

      def collect(self) -> list:
          """Collects all processed rows into a list."""
          return list(self.run())
  '''
end
