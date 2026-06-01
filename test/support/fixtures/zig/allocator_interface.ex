defmodule Test.Fixtures.Zig.AllocatorInterface do
  @moduledoc false
  use Test.LanguageFixture, language: "zig allocator_interface"

  @code ~S'''
  const Allocator = struct {
  ptr: *anyopaque,
  vtable: *const VTable,

  pub const VTable = struct {
    alloc: *const fn (ctx: *anyopaque, len: usize, alignment: u8) ?[*]u8,
    free: *const fn (ctx: *anyopaque, buf: [*]u8, len: usize) void,
    resize: *const fn (ctx: *anyopaque, buf: [*]u8, old_len: usize, new_len: usize) bool,
  };

  pub fn alloc(self: Allocator, comptime T: type, n: usize) ![]T {
    const ptr = self.vtable.alloc(self.ptr, @sizeOf(T) * n, @alignOf(T)) orelse return error.OutOfMemory;
    return @as([*]T, @ptrCast(@alignCast(ptr)))[0..n];
  }

  pub fn free(self: Allocator, slice: anytype) void {
    const T = @TypeOf(slice[0]);
    self.vtable.free(self.ptr, @as([*]u8, @ptrCast(slice.ptr)), slice.len * @sizeOf(T));
  }
  };

  const ArenaAllocator = struct {
  backing: Allocator,
  buffer: []u8,
  pos: usize,

  pub fn init(backing: Allocator, size: usize) !ArenaAllocator {
    const buf = try backing.alloc(u8, size);
    return ArenaAllocator{ .backing = backing, .buffer = buf, .pos = 0 };
  }

  pub fn deinit(self: *ArenaAllocator) void {
    self.backing.free(self.buffer);
  }

  pub fn alloc(self: *ArenaAllocator, comptime T: type, n: usize) ![]T {
    const size = @sizeOf(T) * n;
    if (self.pos + size > self.buffer.len) return error.OutOfMemory;
    const slice = self.buffer[self.pos .. self.pos + size];
    self.pos += size;
    return @as([*]T, @ptrCast(@alignCast(slice.ptr)))[0..n];
  }

  pub fn reset(self: *ArenaAllocator) void {
    self.pos = 0;
  }
  };

  const AllocError = error{
  OutOfMemory,
  AlignmentError,
  InvalidSize,
  };

  fn alignForward(addr: usize, alignment: usize) usize {
  return (addr + alignment - 1) & ~(alignment - 1);
  }

  fn isPowerOfTwo(n: usize) bool {
  return n > 0 and (n & (n - 1)) == 0;
  }

  fn sizeOf(comptime T: type) comptime_int {
  return @sizeOf(T);
  }
  '''
end
