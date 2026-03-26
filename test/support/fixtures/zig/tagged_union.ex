defmodule Test.Fixtures.Zig.TaggedUnion do
  @moduledoc false
  use Test.LanguageFixture, language: "zig tagged_union"

  @code ~S'''
  const TokenKind = enum {
  identifier,
  integer,
  float,
  string_literal,
  operator,
  keyword,
  comment,
  eof,
  };

  const Token = struct {
  kind: TokenKind,
  start: usize,
  end: usize,
  line: u32,
  column: u32,

  pub fn length(self: Token) usize {
    return self.end - self.start;
  }

  pub fn isLiteral(self: Token) bool {
    return self.kind == .integer or self.kind == .float or self.kind == .string_literal;
  }
  };

  const Value = union(enum) {
  int: i64,
  float: f64,
  boolean: bool,
  string: []const u8,
  null_value: void,

  pub fn typeName(self: Value) []const u8 {
    return switch (self) {
      .int => "int",
      .float => "float",
      .boolean => "boolean",
      .string => "string",
      .null_value => "null",
    };
  }

  pub fn isTruthy(self: Value) bool {
    return switch (self) {
      .int => |v| v != 0,
      .float => |v| v != 0.0,
      .boolean => |v| v,
      .string => |v| v.len > 0,
      .null_value => false,
    };
  }
  };

  const ParseError = error{
  UnexpectedToken,
  UnexpectedEof,
  InvalidLiteral,
  StackOverflow,
  };

  fn parseInteger(source: []const u8) !i64 {
  var result: i64 = 0;
  for (source) |ch| {
    if (ch < '0' or ch > '9') return ParseError.InvalidLiteral;
    result = result * 10 + @as(i64, ch - '0');
  }
  return result;
  }

  fn parseFloat(source: []const u8) !f64 {
  var result: f64 = 0;
  var decimal = false;
  var scale: f64 = 1;
  for (source) |ch| {
    if (ch == '.') { decimal = true; continue; }
    if (ch < '0' or ch > '9') return ParseError.InvalidLiteral;
    if (decimal) { scale /= 10; result += @as(f64, ch - '0') * scale; }
    else { result = result * 10 + @as(f64, ch - '0'); }
  }
  return result;
  }
  '''
end
