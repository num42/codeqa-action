defmodule Test.Fixtures.CSharp.LinqPipeline do
  @moduledoc false
  use Test.LanguageFixture, language: "csharp linq_pipeline"

  @code ~S'''
  // DataPipeline namespace — LINQ-style transformation pipeline
  using System.Collections.Generic;
  using System.Linq;

  interface ITransform<TIn, TOut>
  {
    IEnumerable<TOut> Apply(IEnumerable<TIn> input);
  }

  interface IPipeline<T>
  {
    IPipeline<TOut> Pipe<TOut>(ITransform<T, TOut> transform);
    IEnumerable<T> Execute();
  }

  class FilterTransform<T> : ITransform<T, T>
  {
    private readonly System.Func<T, bool> predicate;

    public FilterTransform(System.Func<T, bool> predicate)
    {
      this.predicate = predicate;
    }

    public IEnumerable<T> Apply(IEnumerable<T> input)
    {
      return input.Where(predicate);
    }
  }

  class MapTransform<TIn, TOut> : ITransform<TIn, TOut>
  {
    private readonly System.Func<TIn, TOut> selector;

    public MapTransform(System.Func<TIn, TOut> selector)
    {
      this.selector = selector;
    }

    public IEnumerable<TOut> Apply(IEnumerable<TIn> input)
    {
      return input.Select(selector);
    }
  }

  class DataPipeline<T> : IPipeline<T>
  {
    private readonly IEnumerable<T> source;

    public DataPipeline(IEnumerable<T> source)
    {
      this.source = source;
    }

    public IPipeline<TOut> Pipe<TOut>(ITransform<T, TOut> transform)
    {
      return new DataPipeline<TOut>(transform.Apply(source));
    }

    public IEnumerable<T> Execute()
    {
      return source.ToList();
    }
  }
  '''
end
