defmodule Test.Fixtures.Go.CliParser do
  @moduledoc false
  use Test.LanguageFixture, language: "go cli_parser"

  @code ~S'''
  type Flag struct {
      Name string
      Short string
      Description string
      Required bool
      Value interface{}
  }

  type Command struct {
      Name string
      Description string
      flags []*Flag
      subcommands []*Command
      action func(args []string, flags map[string]interface{}) error
  }

  func NewCommand(name, description string) *Command {
      return &Command{Name: name, Description: description, flags: []*Flag{}, subcommands: []*Command{}}
  }

  func (c *Command) AddFlag(name, short, description string, required bool) *Flag {
      f := &Flag{Name: name, Short: short, Description: description, Required: required}
      c.flags = append(c.flags, f)
      return f
  }

  func (c *Command) AddSubcommand(sub *Command) *Command {
      c.subcommands = append(c.subcommands, sub)
      return c
  }

  func (c *Command) Action(fn func(args []string, flags map[string]interface{}) error) {
      c.action = fn
  }

  func (c *Command) Execute(args []string) error {
      if len(args) > 0 {
          for _, sub := range c.subcommands {
              if sub.Name == args[0] {
                  return sub.Execute(args[1:])
              }
          }
      }
      flags, remaining, err := c.parseFlags(args)
      if err != nil {
          return err
      }
      if c.action != nil {
          return c.action(remaining, flags)
      }
      return nil
  }

  func (c *Command) parseFlags(args []string) (map[string]interface{}, []string, error) {
      result := make(map[string]interface{})
      remaining := []string{}
      for i := 0; i < len(args); i++ {
          arg := args[i]
          if len(arg) > 2 && arg[:2] == "--" {
              key := arg[2:]
              if i+1 < len(args) {
                  result[key] = args[i+1]
                  i++
              }
          } else {
              remaining = append(remaining, arg)
          }
      }
      return result, remaining, nil
  }
  '''
end
