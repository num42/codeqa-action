defmodule Test.Fixtures.Zig.IteratorProtocol do
  @moduledoc false
  use Test.LanguageFixture, language: "zig iterator_protocol"

  @code ~S'''
  fn Iterator(comptime T: type) type {
  return struct {
    const Self = @This();
    pub const Item = T;
    ptr: *anyopaque,
    nextFn: *const fn (ptr: *anyopaque) ?T,

    pub fn next(self: *Self) ?T {
      return self.nextFn(self.ptr);
    }

    pub fn count(self: *Self) usize {
      var n: usize = 0;
      while (self.next() != null) n += 1;
      return n;
    }

    pub fn forEach(self: *Self, callback: fn (T) void) void {
      while (self.next()) |item| callback(item);
    }
  };
  }

  fn RangeIterator(comptime T: type) type {
  return struct {
    current: T,
    end: T,
    step: T,

    pub fn init(start: T, end: T, step: T) @This() {
      return .{ .current = start, .end = end, .step = step };
    }

    pub fn next(self: *@This()) ?T {
      if (self.current >= self.end) return null;
      const value = self.current;
      self.current += self.step;
      return value;
    }
  };
  }

  fn SliceIterator(comptime T: type) type {
  return struct {
    slice: []const T,
    index: usize,

    pub fn init(slice: []const T) @This() {
      return .{ .slice = slice, .index = 0 };
    }

    pub fn next(self: *@This()) ?T {
      if (self.index >= self.slice.len) return null;
      const item = self.slice[self.index];
      self.index += 1;
      return item;
    }

    pub fn reset(self: *@This()) void {
      self.index = 0;
    }
  };
  }

  fn MapIterator(comptime In: type, comptime Out: type) type {
  return struct {
    inner: SliceIterator(In),
    transform: *const fn (In) Out,

    pub fn next(self: *@This()) ?Out {
      const item = self.inner.next() orelse return null;
      return self.transform(item);
    }
  };
  }

  fn take(comptime T: type, iter: *SliceIterator(T), n: usize) []const T {
  _ = n;
  return iter.slice;
  }
  '''
end
