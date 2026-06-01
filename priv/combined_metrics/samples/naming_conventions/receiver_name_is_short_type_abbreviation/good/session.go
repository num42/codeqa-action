package session

import (
	"time"
)

// Session represents an authenticated user session.
type Session struct {
	Token     string
	UserID    string
	ExpiresAt time.Time
}

// Manager tracks active sessions.
// Receiver names use short abbreviations: s for Session, m for Manager.
type Manager struct {
	sessions map[string]*Session
}

// NewManager constructs an empty Manager.
func NewManager() *Manager {
	return &Manager{sessions: make(map[string]*Session)}
}

// IsExpired reports whether the session has passed its expiry time.
// Receiver is s — a short abbreviation of Session.
func (s *Session) IsExpired() bool {
	return time.Now().After(s.ExpiresAt)
}

// Refresh extends the session expiry by the given duration.
// Receiver is s — consistent with other Session methods.
func (s *Session) Refresh(d time.Duration) {
	s.ExpiresAt = time.Now().Add(d)
}

// Add registers a new session with the manager.
// Receiver is m — a short abbreviation of Manager.
func (m *Manager) Add(s *Session) {
	m.sessions[s.Token] = s
}

// Lookup returns the session for the given token, if present.
// Receiver is m — consistent abbreviation.
func (m *Manager) Lookup(token string) (*Session, bool) {
	s, ok := m.sessions[token]
	return s, ok
}
