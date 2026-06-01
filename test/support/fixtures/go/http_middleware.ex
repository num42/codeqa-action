defmodule Test.Fixtures.Go.HttpMiddleware do
  @moduledoc false
  use Test.LanguageFixture, language: "go http_middleware"

  @code ~S'''
  type Handler func(w ResponseWriter, r *Request)

  type Middleware func(Handler) Handler

  type ResponseWriter interface {
      Write([]byte) (int, error)
      WriteHeader(statusCode int)
      Header() map[string][]string
  }

  type Request struct {
      Method string
      Path string
      Headers map[string]string
      Body []byte
  }

  type Router struct {
      routes map[string]Handler
      middlewares []Middleware
  }

  func NewRouter() *Router {
      return &Router{routes: make(map[string]Handler), middlewares: []Middleware{}}
  }

  func (r *Router) Use(m Middleware) {
      r.middlewares = append(r.middlewares, m)
  }

  func (r *Router) Handle(path string, h Handler) {
      r.routes[path] = r.wrap(h)
  }

  func (r *Router) ServeHTTP(w ResponseWriter, req *Request) {
      h, ok := r.routes[req.Path]
      if !ok {
          w.WriteHeader(404)
          return
      }
      h(w, req)
  }

  func (r *Router) wrap(h Handler) Handler {
      for i := len(r.middlewares) - 1; i >= 0; i-- {
          h = r.middlewares[i](h)
      }
      return h
  }

  func LoggingMiddleware(next Handler) Handler {
      return func(w ResponseWriter, r *Request) {
          next(w, r)
      }
  }

  func RecoveryMiddleware(next Handler) Handler {
      return func(w ResponseWriter, r *Request) {
          defer func() {
              if rec := recover(); rec != nil {
                  w.WriteHeader(500)
              }
          }()
          next(w, r)
      }
  }

  func AuthMiddleware(secret string) Middleware {
      return func(next Handler) Handler {
          return func(w ResponseWriter, r *Request) {
              token, ok := r.Headers["Authorization"]
              if !ok || token != secret {
                  w.WriteHeader(401)
                  return
              }
              next(w, r)
          }
      }
  }
  '''
end
