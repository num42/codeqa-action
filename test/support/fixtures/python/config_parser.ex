defmodule Test.Fixtures.Python.ConfigParser do
  @moduledoc false
  use Test.LanguageFixture, language: "python config_parser"

  @code ~S'''
  from dataclasses import dataclass, field
  from typing import ClassVar, Optional


  @dataclass
  class DatabaseConfig:
      """Database connection configuration."""

      host: str = "localhost"
      port: int = 5432
      name: str = "app"
      pool_size: int = 10
      VALID_PORTS: ClassVar[range] = range(1, 65536)

      def __post_init__(self):
          """Validates configuration after initialisation."""
          if self.port not in self.VALID_PORTS:
              raise ValueError(f"Invalid port: {self.port}")
          if not self.host:
              raise ValueError("host must not be empty")
          if self.pool_size < 1:
              raise ValueError("pool_size must be at least 1")

      def url(self) -> str:
          """Returns the database connection URL."""
          return f"postgres://{self.host}:{self.port}/{self.name}"


  @dataclass
  class LoggingConfig:
      """Logging configuration."""

      level: str = "info"
      format: str = "text"
      output: str = "stdout"
      VALID_LEVELS: ClassVar[list] = ["debug", "info", "warning", "error"]
      VALID_FORMATS: ClassVar[list] = ["text", "json"]

      def __post_init__(self):
          """Validates level and format."""
          if self.level not in self.VALID_LEVELS:
              raise ValueError(f"Invalid log level: {self.level}")
          if self.format not in self.VALID_FORMATS:
              raise ValueError(f"Invalid log format: {self.format}")


  @dataclass
  class AppConfig:
      """Top-level application configuration."""

      database: DatabaseConfig = field(default_factory=DatabaseConfig)
      logging: LoggingConfig = field(default_factory=LoggingConfig)
      debug: bool = False
      version: str = "1.0.0"

      def is_production(self) -> bool:
          """Returns True when debug mode is disabled."""
          return not self.debug

      @classmethod
      def from_dict(cls, data: dict) -> "AppConfig":
          """Builds an AppConfig from a plain dictionary."""
          db_data = data.get("database", {})
          log_data = data.get("logging", {})
          return cls(
              database=DatabaseConfig(**db_data),
              logging=LoggingConfig(**log_data),
              debug=data.get("debug", False),
              version=data.get("version", "1.0.0"),
          )

      @classmethod
      def from_env(cls, prefix: str = "APP") -> "AppConfig":
          """Builds an AppConfig from environment variables."""
          import os
          return cls(
              database=DatabaseConfig(
                  host=os.getenv(f"{prefix}_DB_HOST", "localhost"),
                  port=int(os.getenv(f"{prefix}_DB_PORT", "5432")),
              ),
              debug=os.getenv(f"{prefix}_DEBUG", "false").lower() == "true",
          )
  '''
end
