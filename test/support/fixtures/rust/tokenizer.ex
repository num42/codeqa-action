defmodule Test.Fixtures.Rust.Tokenizer do
  @moduledoc false
  use Test.LanguageFixture, language: "rust tokenizer"

  @code ~S'''
  #[derive(Debug, PartialEq, Clone)]
  enum TokenKind {
      Number(f64),
      Plus,
      Minus,
      Star,
      Slash,
      LParen,
      RParen,
      Eof,
  }

  #[derive(Debug, Clone)]
  struct Token {
      kind: TokenKind,
      lexeme: String,
      line: usize,
  }

  impl Token {
      fn new(kind: TokenKind, lexeme: &str, line: usize) -> Self {
          Token { kind, lexeme: lexeme.to_string(), line }
      }

      fn is_operator(&self) -> bool {
          matches!(self.kind, TokenKind::Plus | TokenKind::Minus | TokenKind::Star | TokenKind::Slash)
      }
  }

  impl std::fmt::Display for Token {
      fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
          write!(f, "{:?}({})", self.kind, self.lexeme)
      }
  }

  struct Lexer {
      source: Vec<char>,
      pos: usize,
      line: usize,
  }

  impl Lexer {
      fn new(source: &str) -> Self {
          Lexer { source: source.chars().collect(), pos: 0, line: 1 }
      }

      fn peek(&self) -> Option<char> {
          self.source.get(self.pos).copied()
      }

      fn advance(&mut self) -> Option<char> {
          let ch = self.source.get(self.pos).copied();
          self.pos += 1;
          ch
      }

      fn skip_whitespace(&mut self) {
          while let Some(c) = self.peek() {
              if c == '\n' { self.line += 1; self.pos += 1; }
              else if c.is_whitespace() { self.pos += 1; }
              else { break; }
          }
      }

      fn read_number(&mut self) -> Token {
          let start = self.pos;
          while let Some(c) = self.peek() {
              if c.is_ascii_digit() || c == '.' { self.pos += 1; }
              else { break; }
          }
          let lexeme: String = self.source[start..self.pos].iter().collect();
          let value: f64 = lexeme.parse().unwrap_or(0.0);
          Token::new(TokenKind::Number(value), &lexeme, self.line)
      }

      fn next_token(&mut self) -> Token {
          self.skip_whitespace();
          match self.advance() {
              Some('+') => Token::new(TokenKind::Plus, "+", self.line),
              Some('-') => Token::new(TokenKind::Minus, "-", self.line),
              Some('*') => Token::new(TokenKind::Star, "*", self.line),
              Some('/') => Token::new(TokenKind::Slash, "/", self.line),
              Some('(') => Token::new(TokenKind::LParen, "(", self.line),
              Some(')') => Token::new(TokenKind::RParen, ")", self.line),
              Some(c) if c.is_ascii_digit() => { self.pos -= 1; self.read_number() }
              None => Token::new(TokenKind::Eof, "", self.line),
              _ => Token::new(TokenKind::Eof, "", self.line),
          }
      }

      fn tokenize(&mut self) -> Vec<Token> {
          let mut tokens = Vec::new();
          loop {
              let t = self.next_token();
              let done = t.kind == TokenKind::Eof;
              tokens.push(t);
              if done { break; }
          }
          tokens
      }
  }

  fn tokenize(source: &str) -> Vec<Token> {
      Lexer::new(source).tokenize()
  }
  '''
end
