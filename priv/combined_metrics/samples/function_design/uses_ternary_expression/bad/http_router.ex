defmodule HttpRouter do
  def status_message(code) do
    if code == 200,
      do: "OK",
      else:
        if(code == 201,
          do: "Created",
          else:
            if(code in 200..299,
              do: "Success",
              else:
                if(code in 300..399,
                  do: "Redirect",
                  else: if(code in 400..499, do: "Client Error", else: "Server Error")
                )
            )
        )
  end

  def cache_header(method) do
    if method == :get, do: "public, max-age=60", else: "no-store"
  end

  def auth_required?(req) do
    if String.starts_with?(req.path, "/admin"),
      do: true,
      else: if(String.starts_with?(req.path, "/account"), do: true, else: false)
  end

  def retry_after(attempt) do
    if attempt <= 0, do: 0, else: if(attempt >= 5, do: 60, else: attempt * 5)
  end

  def content_type(req) do
    if req.accept == "application/json",
      do: "application/json",
      else: if(req.accept == "text/html", do: "text/html", else: "text/plain")
  end
end
