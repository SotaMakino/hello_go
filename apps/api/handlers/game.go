package handlers

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strings"

	"example.com/parole/middleware"
)

const (
	WordLength = 5
	MaxGuesses = 5
	// a missed word returns once this many later rounds have been played
	ReviewGap = 3
)

type Games struct {
	DB *sql.DB
}

type game struct {
	id     int64
	word   string
	status string // playing | won | lost
}

type guessResult struct {
	Word   string   `json:"word"`
	Result []string `json:"result"` // per letter: correct | present | absent
}

type gameState struct {
	ID         int64         `json:"id"`
	Status     string        `json:"status"`
	Clue       string        `json:"clue"` // English meaning of the answer
	Guesses    []guessResult `json:"guesses"`
	MaxGuesses int           `json:"maxGuesses"`
	WordLength int           `json:"wordLength"`
	Word       string        `json:"word,omitempty"` // revealed only once the game is over
}

// score returns Wordle feedback for a guess: exact matches first, then
// remaining letters claim "present" slots so duplicates are not over-counted.
func score(word, guess string) []string {
	result := make([]string, len(guess))
	counts := map[byte]int{}
	for i := 0; i < len(word); i++ {
		if guess[i] == word[i] {
			result[i] = "correct"
		} else {
			counts[word[i]]++
		}
	}
	for i := 0; i < len(guess); i++ {
		if result[i] != "" {
			continue
		}
		if counts[guess[i]] > 0 {
			result[i] = "present"
			counts[guess[i]]--
		} else {
			result[i] = "absent"
		}
	}
	return result
}

func (h *Games) latest(user string) (*game, error) {
	g := &game{}
	err := h.DB.QueryRow(
		"SELECT id, word, status FROM games WHERE username = $1 ORDER BY id DESC LIMIT 1",
		user).Scan(&g.id, &g.word, &g.status)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return g, err
}

// nextWord picks the curriculum word for a user's next game. Priority:
//  1. spaced repetition — a word the user lost at least ReviewGap finished
//     rounds ago and has not won since (oldest miss first)
//  2. the first word in curriculum order the user has never played
//  3. the not-yet-won word played longest ago (losses not due yet)
//  4. everything is won: recycle the word won longest ago
func (h *Games) nextWord(user string) (string, error) {
	rows, err := h.DB.Query(
		"SELECT word, status FROM games WHERE username = $1 AND status <> 'playing' ORDER BY id",
		user)
	if err != nil {
		return "", err
	}
	defer rows.Close()
	type outcome struct {
		round int // 1-based index of the user's finished games
		won   bool
	}
	last := map[string]outcome{}
	round := 0
	for rows.Next() {
		var word, status string
		if err := rows.Scan(&word, &status); err != nil {
			return "", err
		}
		round++
		last[word] = outcome{round, status == "won"}
	}
	if err := rows.Err(); err != nil {
		return "", err
	}

	pickOldest := func(match func(outcome) bool) string {
		word, best := "", round+1
		for _, v := range words {
			if o, seen := last[v.Word]; seen && match(o) && o.round < best {
				word, best = v.Word, o.round
			}
		}
		return word
	}

	if w := pickOldest(func(o outcome) bool { return !o.won && round-o.round >= ReviewGap }); w != "" {
		return w, nil
	}
	for _, v := range words {
		if _, seen := last[v.Word]; !seen {
			return v.Word, nil
		}
	}
	if w := pickOldest(func(o outcome) bool { return !o.won }); w != "" {
		return w, nil
	}
	return pickOldest(func(o outcome) bool { return true }), nil
}

func (h *Games) create(user string) (*game, error) {
	word, err := h.nextWord(user)
	if err != nil {
		return nil, err
	}
	g := &game{word: word, status: "playing"}
	err = h.DB.QueryRow(
		"INSERT INTO games (username, word, status) VALUES ($1, $2, 'playing') RETURNING id",
		user, g.word).Scan(&g.id)
	return g, err
}

func (h *Games) state(g *game) (gameState, error) {
	s := gameState{
		ID:         g.id,
		Status:     g.status,
		Clue:       clues[g.word],
		Guesses:    []guessResult{}, // non-nil so an empty list encodes as [], not null
		MaxGuesses: MaxGuesses,
		WordLength: WordLength,
	}
	rows, err := h.DB.Query("SELECT guess FROM guesses WHERE game_id = $1 ORDER BY id", g.id)
	if err != nil {
		return s, err
	}
	defer rows.Close()
	for rows.Next() {
		var guess string
		if err := rows.Scan(&guess); err != nil {
			return s, err
		}
		s.Guesses = append(s.Guesses, guessResult{Word: guess, Result: score(g.word, guess)})
	}
	if g.status != "playing" {
		s.Word = g.word
	}
	return s, rows.Err()
}

func (h *Games) writeState(w http.ResponseWriter, code int, g *game) {
	s, err := h.state(g)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(s)
}

// Current returns the user's latest game, starting one if they have none yet.
func (h *Games) Current(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil {
		if g, err = h.create(user); err != nil {
			writeError(w, http.StatusInternalServerError, "could not start a game")
			return
		}
	}
	h.writeState(w, http.StatusOK, g)
}

// New starts a fresh game once the current one is finished.
func (h *Games) New(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g != nil && g.status == "playing" {
		writeError(w, http.StatusConflict, "finish the current game first")
		return
	}
	g, err = h.create(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "could not start a game")
		return
	}
	h.writeState(w, http.StatusCreated, g)
}

// Guess submits one guess for the current game.
func (h *Games) Guess(w http.ResponseWriter, r *http.Request) {
	user := middleware.Username(r)
	var body struct {
		Guess string `json:"guess"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid JSON")
		return
	}
	guess := strings.ToUpper(strings.TrimSpace(body.Guess))
	if len(guess) != WordLength || strings.IndexFunc(guess, func(r rune) bool {
		return r < 'A' || r > 'Z'
	}) != -1 {
		writeError(w, http.StatusBadRequest, "guess must be a 5-letter word")
		return
	}
	if !wordSet[guess] {
		writeError(w, http.StatusBadRequest, "not in the word list")
		return
	}

	g, err := h.latest(user)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}
	if g == nil || g.status != "playing" {
		writeError(w, http.StatusConflict, "no game in progress")
		return
	}

	if _, err := h.DB.Exec(
		"INSERT INTO guesses (game_id, guess) VALUES ($1, $2)", g.id, guess); err != nil {
		writeError(w, http.StatusInternalServerError, "could not save guess")
		return
	}
	var count int
	if err := h.DB.QueryRow(
		"SELECT count(*) FROM guesses WHERE game_id = $1", g.id).Scan(&count); err != nil {
		writeError(w, http.StatusInternalServerError, "query failed")
		return
	}

	switch {
	case guess == g.word:
		g.status = "won"
	case count >= MaxGuesses:
		g.status = "lost"
	}
	if g.status != "playing" {
		if _, err := h.DB.Exec("UPDATE games SET status = $1 WHERE id = $2", g.status, g.id); err != nil {
			writeError(w, http.StatusInternalServerError, "could not update game")
			return
		}
	}
	h.writeState(w, http.StatusOK, g)
}

func writeError(w http.ResponseWriter, code int, msg string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}
