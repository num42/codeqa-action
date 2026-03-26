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
type Manager struct {
	sessions map[string]*Session
}

// NewManager constructs an empty Manager.
func NewManager() *Manager {
	return &Manager{sessions: make(map[string]*Session)}
}

// IsExpired reports whether the session has passed its expiry time.
// Receiver is named "self" — not idiomatic Go; should be "s".
func (self *Session) IsExpired() bool {
	return time.Now().After(self.ExpiresAt)
}

// Refresh extends the session expiry by the given duration.
// Receiver is named "this" — not idiomatic Go; should be "s".
func (this *Session) Refresh(d time.Duration) {
	this.ExpiresAt = time.Now().Add(d)
}

// Add registers a new session with the manager.
// Receiver is named "me" — not idiomatic Go; should be "m".
func (me *Manager) Add(s *Session) {
	me.sessions[s.Token] = s
}

// Lookup returns the session for the given token, if present.
// Receiver is named "mgr" — verbose, inconsistent with other methods.
func (mgr *Manager) Lookup(token string) (*Session, bool) {
	s, ok := mgr.sessions[token]
	return s, ok
}
