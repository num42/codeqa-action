defmodule CodeQA.Research.Github do
  @moduledoc """
  GitHub API wrapper using the `gh` CLI.
  All functions return {:ok, result} | {:error, reason}.
  """

  @per_page 20

  @doc """
  Fetch the top `count` most-starred repos for a given language.
  Returns list of %{owner: String, name: String, stars: integer, full_name: String}.
  """
  @spec fetch_top_repos(language :: String.t(), count :: pos_integer()) ::
          {:ok, list(map())} | {:error, String.t()}
  def fetch_top_repos(language, count \\ @per_page) do
    query = "language:#{language} is:public archived:false"
    path = "/search/repositories?q=#{URI.encode(query)}&sort=stars&order=desc&per_page=#{count}"

    case gh_api(path) do
      {:ok, %{"items" => items}} ->
        repos =
          Enum.map(items, fn item ->
            %{
              owner: item["owner"]["login"],
              name: item["name"],
              full_name: item["full_name"],
              stars: item["stargazers_count"],
              language: language
            }
          end)

        {:ok, repos}

      {:ok, other} ->
        {:error, "unexpected response shape: #{inspect(other)}"}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Fetch all tags for a repo. Returns list of %{name: String, sha: String}.
  Paginates automatically up to 500 tags.
  """
  @spec fetch_tags(owner :: String.t(), repo :: String.t()) ::
          {:ok, list(map())} | {:error, String.t()}
  def fetch_tags(owner, repo) do
    fetch_paginated("/repos/#{owner}/#{repo}/tags", "name", fn item ->
      %{name: item["name"], sha: item["commit"]["sha"]}
    end)
  end

  @doc """
  Fetch commit messages between two refs (base..head).
  Returns list of commit message strings.
  """
  @spec fetch_commits_between(
          owner :: String.t(),
          repo :: String.t(),
          base :: String.t(),
          head :: String.t()
        ) :: {:ok, list(String.t())} | {:error, String.t()}
  def fetch_commits_between(owner, repo, base, head) do
    # NOTE: GitHub compare endpoint caps at 100 commits per request and does not
    # support pagination the same way as list endpoints. Transitions with >100
    # commits will be silently truncated to the first 100. This is a known
    # limitation: for very long-lived transitions (many commits), the commit
    # classification reflects only the first 100 commits. In practice, PATCH
    # transitions rarely exceed 100 commits, so the impact is mainly on MINOR
    # and MAJOR transitions in high-velocity repos.
    path = "/repos/#{owner}/#{repo}/compare/#{base}...#{head}?per_page=100"

    case gh_api(path) do
      {:ok, %{"commits" => commits}} ->
        messages = Enum.map(commits, fn c -> c["commit"]["message"] end)
        {:ok, messages}

      {:ok, _other} ->
        {:ok, []}

      {:error, _} = err ->
        err
    end
  end

  # --- Private ---

  # Paginates up to 500 results (5 pages × 100). Accumulates in reverse for
  # O(n) list building, then reverses at the end. Warns when the cap is hit
  # so callers know results may be truncated (e.g. very active repos).
  defp fetch_paginated(path, key_field, mapper, acc \\ [], page \\ 1) do
    paginated_path = "#{path}?per_page=100&page=#{page}"

    case gh_api(paginated_path) do
      {:ok, items} when is_list(items) and length(items) == 100 and page < 5 ->
        fetch_paginated(path, key_field, mapper, [Enum.map(items, mapper) | acc], page + 1)

      {:ok, items} when is_list(items) and length(items) == 100 and page == 5 ->
        IO.warn("fetch_paginated: reached 500-item cap for #{path}; results may be truncated")
        {:ok, [Enum.map(items, mapper) | acc] |> Enum.reverse() |> List.flatten()}

      {:ok, items} when is_list(items) ->
        {:ok, [Enum.map(items, mapper) | acc] |> Enum.reverse() |> List.flatten()}

      {:ok, _} ->
        {:ok, acc |> Enum.reverse() |> List.flatten()}

      {:error, _} = err ->
        err
    end
  end

  defp gh_api(path) do
    case System.cmd("gh", ["api", path], stderr_to_stdout: true) do
      {output, 0} ->
        case Jason.decode(output) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _} -> {:error, "JSON parse error: #{String.slice(output, 0, 200)}"}
        end

      {output, code} ->
        {:error, "gh api exited #{code}: #{String.slice(output, 0, 200)}"}
    end
  end
end
