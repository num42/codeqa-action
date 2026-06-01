// Query/struct builder — BAD: intermediate variables used exactly once.
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
	base := From("products")
	withCategory := base.Where("category", f.Category)
	withPrice := withCategory.WhereLte("price", f.MaxPrice)
	withStock := withPrice.WhereGt("stock", 0)
	ordered := withStock.OrderBy("inserted_at")
	limited := ordered.Limit(f.Limit)
	return limited
}

func (QueryBuilder) BuildUser(name, email, role string) User {
	trimmedName := strings.TrimSpace(name)
	loweredEmail := strings.ToLower(email)
	resolvedRole := role
	if resolvedRole == "" {
		resolvedRole = "guest"
	}
	user := User{Name: trimmedName, Email: loweredEmail, Role: resolvedRole}
	return user
}

func (b QueryBuilder) FormatReport(d ReportData) string {
	title := strings.ToUpper(d.Title)
	header := fmt.Sprintf("=== %s ===", title)
	lines := make([]string, len(d.Rows))
	for i, r := range d.Rows {
		line := b.formatRow(r)
		lines[i] = line
	}
	body := strings.Join(lines, "\n")
	report := header + "\n" + body
	return report
}

func (QueryBuilder) BuildNotification(e Event) map[string]string {
	subject := fmt.Sprintf("Event: %s", e.Name)
	recipient := e.User.Email
	template := loadTemplate(e.Type)
	rendered := renderTemplate(template, e)
	notification := map[string]string{"subject": subject, "to": recipient, "body": rendered}
	return notification
}

func (QueryBuilder) ComposeURL(baseURL, path string, params url.Values) string {
	encoded := params.Encode()
	fullPath := fmt.Sprintf("%s?%s", path, encoded)
	full := baseURL + fullPath
	return full
}

func (QueryBuilder) formatRow(r Row) string {
	label := r.Label
	value := r.Value
	line := fmt.Sprintf("%s: %s", label, value)
	return line
}

func loadTemplate(t string) string {
	name := "template_" + t
	return name
}

func renderTemplate(t string, _ Event) string { return t }

type Query struct{}

func From(_ string) *Query                       { return &Query{} }
func (q *Query) Where(_, _ interface{}) *Query   { return q }
func (q *Query) WhereLte(_ string, _ float64) *Query { return q }
func (q *Query) WhereGt(_ string, _ int) *Query  { return q }
func (q *Query) OrderBy(_ string) *Query         { return q }
func (q *Query) Limit(_ int) *Query              { return q }
