package store

import (
	"database/sql"

	_ "github.com/jackc/pgx/v5/stdlib"
)

func Open(url string) (*sql.DB, error) {
	db, err := sql.Open("pgx", url)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		return nil, err
	}
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS accounts (
		username TEXT PRIMARY KEY,
		password_hash TEXT NOT NULL
	)`)
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS sessions (
		token TEXT PRIMARY KEY,
		username TEXT NOT NULL,
		expires_at TIMESTAMPTZ NOT NULL
	)`)
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS games (
		id BIGSERIAL PRIMARY KEY,
		username TEXT NOT NULL,
		word TEXT NOT NULL,
		status TEXT NOT NULL DEFAULT 'playing'
	)`)
	// "it" spells the English word (default); "en" spells the Italian one
	_, err = db.Exec(`ALTER TABLE games ADD COLUMN IF NOT EXISTS direction TEXT NOT NULL DEFAULT 'it'`)
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS guesses (
		id BIGSERIAL PRIMARY KEY,
		game_id BIGINT NOT NULL REFERENCES games(id) ON DELETE CASCADE,
		guess TEXT NOT NULL
	)`)
	return db, err
}
