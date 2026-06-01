// Query/struct builder — GOOD: intermediate results are inlined or chained.
package querybuilder

import (
	"fmt"
	"net/url"
	"strings"
)

type Filters struct {
	Category string
	MaxPrice float64
	Limit    int
}

type User struct {
	Name  string
	Email string
	Role  string
}

type Row struct {
	Label string
	Value string
}

type ReportData struct {
	Title string
	Rows  []Row
}

type Event struct {
	Name string
	Type string
	User struct{ Email string }
}

type QueryBuilder struct{}

func (QueryBuilder) BuildSearchQuery(f Filters) *Query {
	return From("products").
		Where("category", f.Category).
		WhereLte("price", f.MaxPrice).
		WhereGt("stock", 0).
		OrderBy("inserted_at").
		Limit(f.Limit)
}

func (QueryBuilder) BuildUser(name, email, role string) User {
	if role == "" {
		role = "guest"
	}
	return User{
		Name:  strings.TrimSpace(name),
		Email: strings.ToLower(email),
		Role:  role,
	}
}

func (b QueryBuilder) FormatReport(d ReportData) string {
	header := fmt.Sprintf("=== %s ===", strings.ToUpper(d.Title))
	lines := make([]string, len(d.Rows))
	for i, r := range d.Rows {
		lines[i] = b.formatRow(r)
	}
	return header + "\n" + strings.Join(lines, "\n")
}

func (QueryBuilder) BuildNotification(e Event) map[string]string {
	return map[string]string{
		"subject": fmt.Sprintf("Event: %s", e.Name),
		"to":      e.User.Email,
		"body":    renderTemplate(loadTemplate(e.Type), e),
	}
}

func (QueryBuilder) ComposeURL(baseURL, path string, params url.Values) string {
	return fmt.Sprintf("%s%s?%s", baseURL, path, params.Encode())
}

func (QueryBuilder) formatRow(r Row) string {
	return fmt.Sprintf("%s: %s", r.Label, r.Value)
}

func loadTemplate(t string) string         { return "template_" + t }
func renderTemplate(t string, _ Event) string { return t }

type Query struct{}

func From(_ string) *Query                       { return &Query{} }
func (q *Query) Where(_, _ interface{}) *Query   { return q }
func (q *Query) WhereLte(_ string, _ float64) *Query { return q }
func (q *Query) WhereGt(_ string, _ int) *Query  { return q }
func (q *Query) OrderBy(_ string) *Query         { return q }
func (q *Query) Limit(_ int) *Query              { return q }
