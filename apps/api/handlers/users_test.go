package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"

	"example.com/hello-go/store"
)

func setupDB(t *testing.T) *sql.DB {
	t.Helper()
	url := os.Getenv("TEST_DATABASE_URL")
	if url == "" {
		url = "postgres://localhost:5432/hellodb_test"
	}
	db, err := store.Open(url)
	if err != nil {
		t.Skipf("postgres unavailable: %v", err)
	}
	t.Cleanup(func() { db.Close() })
	if _, err := db.Exec("TRUNCATE users, accounts, sessions"); err != nil {
		t.Fatal(err)
	}
	return db
}

func setup(t *testing.T) *Users {
	return &Users{DB: setupDB(t)}
}

func TestCreateUser(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("POST", "/users",
		strings.NewReader(`{"id":"1","name":"Ann"}`))
	rec := httptest.NewRecorder()

	h.Create(rec, req)

	if rec.Code != http.StatusCreated {
		t.Errorf("expected 201, got %d", rec.Code)
	}
}

func TestCreateUser_EmptyName(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("POST", "/users",
		strings.NewReader(`{"id":"1","name":""}`))
	rec := httptest.NewRecorder()

	h.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
}

func TestCreateUser_InvalidJSON(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("POST", "/users", strings.NewReader(`not json`))
	rec := httptest.NewRecorder()

	h.Create(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
}

func TestCreateUser_Duplicate(t *testing.T) {
	h := setup(t)

	for i, want := range []int{http.StatusCreated, http.StatusConflict} {
		req := httptest.NewRequest("POST", "/users",
			strings.NewReader(`{"id":"1","name":"Ann"}`))
		rec := httptest.NewRecorder()

		h.Create(rec, req)

		if rec.Code != want {
			t.Errorf("request %d: expected %d, got %d", i+1, want, rec.Code)
		}
	}
}

func TestGetUser(t *testing.T) {
	h := setup(t)
	if _, err := h.DB.Exec("INSERT INTO users (id, name) VALUES ($1, $2)", "1", "Ann"); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest("GET", "/users/1", nil)
	req.SetPathValue("id", "1")
	rec := httptest.NewRecorder()

	h.Get(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var u User
	if err := json.NewDecoder(rec.Body).Decode(&u); err != nil {
		t.Fatal(err)
	}
	if u.ID != "1" || u.Name != "Ann" {
		t.Errorf("expected {1 Ann}, got %+v", u)
	}
}

func TestGetUser_NotFound(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("GET", "/users/999", nil)
	req.SetPathValue("id", "999")
	rec := httptest.NewRecorder()

	h.Get(rec, req)

	if rec.Code != http.StatusNotFound {
		t.Errorf("expected 404, got %d", rec.Code)
	}
}

func TestListUsers_Empty(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("GET", "/users", nil)
	rec := httptest.NewRecorder()

	h.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	if got := strings.TrimSpace(rec.Body.String()); got != "[]" {
		t.Errorf("expected [], got %s", got)
	}
}

func TestListUsers(t *testing.T) {
	h := setup(t)
	for _, u := range []User{{"1", "Ann"}, {"2", "Bob"}} {
		if _, err := h.DB.Exec("INSERT INTO users (id, name) VALUES ($1, $2)", u.ID, u.Name); err != nil {
			t.Fatal(err)
		}
	}

	req := httptest.NewRequest("GET", "/users", nil)
	rec := httptest.NewRecorder()

	h.List(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var users []User
	if err := json.NewDecoder(rec.Body).Decode(&users); err != nil {
		t.Fatal(err)
	}
	if len(users) != 2 {
		t.Errorf("expected 2 users, got %d", len(users))
	}
}

func TestUpdateUser(t *testing.T) {
	h := setup(t)
	if _, err := h.DB.Exec("INSERT INTO users (id, name) VALUES ($1, $2)", "1", "Ann"); err != nil {
		t.Fatal(err)
	}

	req := httptest.NewRequest("PUT", "/users/1", strings.NewReader(`{"name":"Anna"}`))
	req.SetPathValue("id", "1")
	rec := httptest.NewRecorder()

	h.Update(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	var name string
	if err := h.DB.QueryRow("SELECT name FROM users WHERE id = $1", "1").Scan(&name); err != nil {
		t.Fatal(err)
	}
	if name != "Anna" {
		t.Errorf("expected name Anna in DB, got %s", name)
	}
}

func TestUpdateUser_InvalidJSON(t *testing.T) {
	h := setup(t)

	req := httptest.NewRequest("PUT", "/users/1", strings.NewReader(`not json`))
	req.SetPathValue("id", "1")
	rec := httptest.NewRecorder()

	h.Update(rec, req)

	if rec.Code != http.StatusBadRequest {
		t.Errorf("expected 400, got %d", rec.Code)
	}
}
