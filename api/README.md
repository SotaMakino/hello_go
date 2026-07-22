# API

Go backend for Le Cinque. In production it runs on Render; the frontend reaches
it same-origin through the Cloudflare Pages `/api/*` proxy.

## Environment variables

| Variable | Default | Purpose |
| --- | --- | --- |
| `PORT` | `8080` | Port to listen on. |
| `DATABASE_URL` | `postgres://localhost:5432/hellodb` | Postgres connection string. |
| `ALLOWED_ORIGIN` | `http://localhost:5173` | Comma-separated CORS origins. |
| `GOOGLE_TTS_CREDENTIALS` | _(unset)_ | Service-account key JSON for word pronunciation (see below). Unset → pronunciation falls back to browser speech. |

## Word pronunciation (Google Cloud TTS)

The 🔊 button pronounces Italian words. Chromium browsers use their own good
built-in voice; Firefox and Safari only expose a low-quality voice, so for those
the frontend fetches natural audio from `GET /tts`, which calls Google Cloud
Text-to-Speech. Synthesised MP3s are cached in memory (the vocabulary is small
and fixed), keeping usage well inside the free tier.

To enable it:

1. In Google Cloud, **enable the Cloud Text-to-Speech API** on your project.
2. Create a **service account** and download its **JSON key**.
3. Set `GOOGLE_TTS_CREDENTIALS` to the **full contents** of that JSON file
   (on Render: a normal env var; the value is the whole `{ … }` object).

Without it, `/tts` returns `503` and the app falls back to browser speech, so
the game still works — Firefox/Safari just get the lower-quality voice.
