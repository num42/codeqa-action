defmodule Test.Fixtures.Ruby.MarkdownRenderer do
  @moduledoc false
  use Test.LanguageFixture, language: "ruby markdown_renderer"

  @code ~S'''
  module Markdown
    Token = Struct.new(:type, :content, :level)
  end

  module Markdown::Tokenizer
    HEADING_RE = /^(#{1,6})\s+(.+)$/
    CODE_BLOCK_RE = /^```(\w*)$/
    BOLD_RE = /\*\*(.+?)\*\*/
    ITALIC_RE = /\*(.+?)\*/
    LINK_RE = /\[(.+?)\]\((.+?)\)/

    def tokenize_line(line)
      case line
      when HEADING_RE
        Markdown::Token.new(:heading, Regexp.last_match(2), Regexp.last_match(1).length)
      when /^\s*[-*]\s+(.+)/
        Markdown::Token.new(:list_item, Regexp.last_match(1), 0)
      when /^\s*$/
        Markdown::Token.new(:blank, "", 0)
      else
        Markdown::Token.new(:paragraph, line, 0)
      end
    end

    def inline_format(text)
      text
        .gsub(LINK_RE) { "<a href=\"#{Regexp.last_match(2)}\">#{Regexp.last_match(1)}</a>" }
        .gsub(BOLD_RE) { "<strong>#{Regexp.last_match(1)}</strong>" }
        .gsub(ITALIC_RE) { "<em>#{Regexp.last_match(1)}</em>" }
    end
  end

  module Markdown::Renderer
    include Markdown::Tokenizer

    def render_token(token)
      case token.type
      when :heading
        "<h#{token.level}>#{inline_format(token.content)}</h#{token.level}>"
      when :list_item
        "<li>#{inline_format(token.content)}</li>"
      when :paragraph
        "<p>#{inline_format(token.content)}</p>"
      when :blank
        ""
      end
    end

    def render(markdown)
      markdown.lines.map { |line| tokenize_line(line.chomp) }.map { |token| render_token(token) }.reject(&:empty?).join("\n")
    end
  end

  class Markdown::Document
    include Markdown::Renderer

    def initialize(source)
      @source = source
    end

    def to_html
      render(@source)
    end

    def word_count
      @source.split(/\s+/).length
    end

    def heading_count
      @source.lines.count { |l| l.match?(HEADING_RE) }
    end
  end
  '''
end
