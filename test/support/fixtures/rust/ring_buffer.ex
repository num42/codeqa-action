defmodule Test.Fixtures.Rust.RingBuffer do
  @moduledoc false
  use Test.LanguageFixture, language: "rust ring_buffer"

  @code ~S'''
  struct RingBuffer<T> {
      data: Vec<Option<T>>,
      head: usize,
      tail: usize,
      len: usize,
      capacity: usize,
  }

  impl<T> RingBuffer<T> {
      fn new(capacity: usize) -> Self {
          let data = (0..capacity).map(|_| None).collect();
          RingBuffer { data, head: 0, tail: 0, len: 0, capacity }
      }

      fn push(&mut self, value: T) -> bool {
          if self.len == self.capacity {
              return false;
          }
          self.data[self.tail] = Some(value);
          self.tail = (self.tail + 1) % self.capacity;
          self.len += 1;
          true
      }

      fn pop(&mut self) -> Option<T> {
          if self.len == 0 {
              return None;
          }
          let value = self.data[self.head].take();
          self.head = (self.head + 1) % self.capacity;
          self.len -= 1;
          value
      }

      fn peek(&self) -> Option<&T> {
          if self.len == 0 { None } else { self.data[self.head].as_ref() }
      }

      fn is_empty(&self) -> bool {
          self.len == 0
      }

      fn is_full(&self) -> bool {
          self.len == self.capacity
      }

      fn len(&self) -> usize {
          self.len
      }

      fn capacity(&self) -> usize {
          self.capacity
      }

      fn clear(&mut self) {
          for slot in self.data.iter_mut() {
              *slot = None;
          }
          self.head = 0;
          self.tail = 0;
          self.len = 0;
      }
  }

  impl<T: Clone> RingBuffer<T> {
      fn to_vec(&self) -> Vec<T> {
          (0..self.len)
              .filter_map(|i| self.data[(self.head + i) % self.capacity].clone())
              .collect()
      }
  }

  fn fill_buffer<T: Clone>(items: &[T], capacity: usize) -> RingBuffer<T> {
      let mut buf = RingBuffer::new(capacity);
      for item in items {
          buf.push(item.clone());
      }
      buf
  }
  '''
end
