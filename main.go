package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"time"

	_ "modernc.org/sqlite"
)

type User struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

var db *sql.DB

func getUser(w http.ResponseWriter, r *http.Request) {
	var u User
	err := db.QueryRow("SELECT id, name FROM users WHERE id = ?", r.PathValue("id")).
		Scan(&u.ID, &u.Name)
	if err == sql.ErrNoRows {
		http.Error(w, "user not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(u)
}

func createUser(w http.ResponseWriter, r *http.Request) {
	var u User
	if err := json.NewDecoder(r.Body).Decode(&u); err != nil {
		http.Error(w, "invalid JSON", http.StatusBadRequest)
		return
	}
	_, err := db.Exec("INSERT INTO users (id, name) VALUES (?, ?)", u.ID, u.Name)
	if err != nil {
		http.Error(w, "could not create user", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(u)
}

func main() {
	start := time.Now()

	var err error
	db, err = sql.Open("sqlite", "app.db")
	if err != nil {
		panic(err)
	}
	db.Exec(`CREATE TABLE IF NOT EXISTS users (id TEXT PRIMARY KEY, name TEXT)`)
	log.Printf("database ready in %s", time.Since(start))

	mux := http.NewServeMux()
	mux.HandleFunc("GET /users/{id}", getUser)
	mux.HandleFunc("POST /users", createUser)

	log.Printf("server starting on :8080 (total startup: %s)", time.Since(start))
	http.ListenAndServe(":8080", mux)
}
