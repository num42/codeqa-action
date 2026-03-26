defmodule Test.Fixtures.CSharp.PluginSystem do
  @moduledoc false
  use Test.LanguageFixture, language: "csharp plugin_system"

  @code ~S'''
  // PluginSystem namespace — plugin registry with lifecycle management
  using System.Collections.Generic;

  interface IPlugin
  {
    string Name { get; }
    string Version { get; }
    void Initialize(IPluginContext context);
    void Shutdown();
  }

  interface IPluginContext
  {
    void RegisterService<T>(T service) where T : class;
    T ResolveService<T>() where T : class;
    void Log(string message);
  }

  interface IPluginRegistry
  {
    void Register(IPlugin plugin);
    void Unregister(string name);
    IPlugin Find(string name);
    IEnumerable<IPlugin> All();
  }

  class PluginContext : IPluginContext
  {
    private readonly Dictionary<System.Type, object> services = new Dictionary<System.Type, object>();

    public void RegisterService<T>(T service) where T : class { services[typeof(T)] = service; }

    public T ResolveService<T>() where T : class
    {
      if (services.TryGetValue(typeof(T), out var svc)) return (T)svc;
      throw new System.InvalidOperationException("Service not found: " + typeof(T).Name);
    }

    public void Log(string message) { System.Console.WriteLine("[Plugin] " + message); }
  }

  class PluginRegistry : IPluginRegistry
  {
    private readonly Dictionary<string, IPlugin> plugins = new Dictionary<string, IPlugin>();
    private readonly IPluginContext context;

    public PluginRegistry(IPluginContext context) { this.context = context; }

    public void Register(IPlugin plugin)
    {
      plugin.Initialize(context);
      plugins[plugin.Name] = plugin;
    }

    public void Unregister(string name)
    {
      if (plugins.TryGetValue(name, out var plugin)) { plugin.Shutdown(); plugins.Remove(name); }
    }

    public IPlugin Find(string name) { plugins.TryGetValue(name, out var p); return p; }

    public IEnumerable<IPlugin> All() { return plugins.Values; }
  }

  enum PluginState { Unloaded, Initializing, Active, ShuttingDown }
  '''
end
