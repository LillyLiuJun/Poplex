<p align="center">
  <img src="docs/brand/readme-banner.png" alt="Poplex — Build language from your own life. 从你自己的生活里学语言。" width="100%">
</p>

# Poplex

**Build language from your own life.** Poplex is an AI-native iOS app that turns the
moments around you — a photo, a few words, a passing thought — into scene-based
language you can actually say out loud.

> **Current stage:** Poplex currently supports **Chinese → English**.

[中文说明](README.zh-CN.md)

> **Source-available, not open source.** The code is published under the
> [PolyForm Noncommercial License 1.0.0](LICENSE). You may read it, learn from it,
> run it and modify it for noncommercial purposes. **Commercial use is not granted
> by this license.** The Poplex name, logo and design are not licensed — see
> [License](#license) and [NOTICE](NOTICE).

## What it does

Poplex turns the moments of your life into language that is yours: the expressions
you actually need, organised for you automatically — so everything you capture
becomes something you can use.

### Today (Tab 1) — capture and generate

Type a sentence or add a photo (camera or gallery). The AI turns it into a learning
card with both languages side by side: write in Chinese and get the English you wanted
to say; write in English and get its meaning in Chinese; send a photo and get an English
sentence for the scene. You can keep asking about the same scene.

### Library (Tab 2) — your material, organised for you

Nothing to sort by hand. Everything you capture is organised automatically:

- **Auto-categorised** into life topics.
- **Scenes grouped automatically**, so moments from the same situation sit together.
- **Broken down into expressions** — words, phrases, collocations, idioms, sentence
  patterns — de-duplicated across everything you capture, each remembering the scenes
  it came from.

A topic unlocks once it has collected 20 expressions.

### Anonymous by design

No sign-up, no email: the app signs in anonymously on first launch and everything a
user creates stays private to that account. Account deletion removes the account and
all of its data.

The interface is English; each card pairs English with its Chinese meaning.

## Architecture

```
iOS app (SwiftUI, iOS 17+)
   │  HTTPS, user JWT
   ▼
Supabase Edge Functions (Deno / TypeScript)   ← the only place that talks to the AI provider
   │                         │
   ▼                         ▼
Postgres (RLS) + Storage     Google Gemini (gemini-3.7-flash)
```

- **The app never holds an AI key.** Every AI request goes through an Edge Function;
  the provider key exists only in the function's environment.
- **Edge Functions verify the caller's JWT** against Supabase Auth, write
  `user_id`, and filter every read by it. Tables have row-level security as defence
  in depth.
- Swapping the AI provider only touches the Edge Functions.

| Layer | Technology |
|---|---|
| App | Swift 5, SwiftUI, `@Observable`, `NavigationStack`, iOS 17+, iPhone only |
| Backend | Supabase: Postgres, Auth (anonymous), Storage, Edge Functions |
| AI | Google Gemini, called server-side only |
| Tests | Swift Testing + XCTest (UI launch / toast regression), Deno tests, pgTAP |

### Edge Functions (`supabase/functions/`)

| Function | Role |
|---|---|
| `generate` | Core pipeline: input → learning cards → materials, plus lexicon accounting |
| `get-messages`, `get-materials`, `get-vocabs`, `get-tab2-home`, `get-category-words` | Reads for Tab 1 and Tab 2 |
| `save-preset-card`, `delete-material`, `restore-material` | Writes on materials |
| `backfill-lexicon`, `reconcile-orphan-images` | Manual maintenance jobs |
| `delete-account`, `submit-feedback`, `log-event` | Account, feedback and analytics |

Schema changes live in `supabase/migrations/` (replayed from scratch by CI).

## Repository layout

```
AIEnglishApp/          iOS app — Today/ (Tab 1), Mine/ (Tab 2), Onboarding/, Settings/,
                       Services/, Models/, Theme/ (design tokens)
AIEnglishAppTests/     unit tests
AIEnglishAppUITests/   UI launch and toast regression tests
supabase/              Edge Functions, SQL migrations, database tests
scripts/ci/            verification and PR scripts used locally and by CI
docs/                  PRDs, architecture, design system, brand, engineering notes
legal/                 privacy policy, terms and support pages
CLAUDE.md, AGENTS.md   project briefs for AI coding assistants
```

Most documents under `docs/` are written in Chinese, and a few refer to internal working files
(for example under `docs/review/`, `docs/testing/` or `docs/design-demos/`) that are not published. Start here:

- [`docs/prd/整体架构_两个Tab与对话页_v1.md`](docs/prd/整体架构_两个Tab与对话页_v1.md) — product structure (Tab 1 / Tab 2)
- [`docs/prd/Agent内容组织与成长系统_PRD_v2.md`](docs/prd/Agent内容组织与成长系统_PRD_v2.md) — Tab 2, the lexicon ledger, growth layer
- [`docs/engineering/CI.md`](docs/engineering/CI.md) — pull-request verification
- [`docs/architecture/AI协作手册.md`](docs/architecture/AI协作手册.md) — how work is split between the owner and AI assistants
- [`docs/brand/README.md`](docs/brand/README.md) — brand assets and rules
- [`docs/design-system/`](docs/design-system/) — typography and component specs (colours: `AIEnglishApp/Theme/Theme.swift`)
- [`CLAUDE.md`](CLAUDE.md) — design rules, working method, decided trade-offs, current state

## Running it yourself

The repository does **not** point at a real backend. To run the app you need your
own Supabase project and Gemini API key.

1. **Create a Supabase project** and enable **anonymous sign-ins**
   (Authentication → Sign In / Providers).
2. **Apply the migrations.** Run the SQL files in `supabase/migrations/` in
   filename order against your project (the Supabase CLI can do this; copy
   `supabase/config.toml.example` to `supabase/config.toml` first, so the CLI
   treats the folder as a Supabase project).
3. **Create a private Storage bucket** named `material_images`.
4. **Deploy the Edge Functions** in `supabase/functions/` and set their secrets.
   Supabase injects `SUPABASE_URL`, `SUPABASE_ANON_KEY` and
   `SUPABASE_SERVICE_ROLE_KEY` itself; you must set `GEMINI_API_KEY`
   (and `RECONCILE_SECRET` if you use the orphan-image reconciler).
5. **Point the app at your project.** Edit
   `AIEnglishApp/Services/SupabaseConfig.swift` and replace the two placeholders,
   `https://YOUR-PROJECT-REF.supabase.co` and `YOUR_SUPABASE_PUBLISHABLE_KEY`.
6. **Open `AIEnglishApp.xcodeproj` in Xcode**, set your own Team and Bundle
   Identifier (the project is configured for the author's), and run on an
   iOS 17+ simulator or device.

A new project starts empty. Add a few entries in Today first; Library topics
unlock once a topic has collected 20 expressions.

Never put the Gemini key or the service-role key in the app.

### Tests

```bash
bash scripts/ci/test-ios.sh
bash scripts/ci/test-edge-functions.sh
ALLOW_LOCAL_SUPABASE_RESET=1 bash scripts/ci/test-database.sh   # resets the local database
```

See [`docs/engineering/CI.md`](docs/engineering/CI.md) for what each script checks.

## License

- **Code:** [PolyForm Noncommercial License 1.0.0](LICENSE). Personal study,
  research, hobby projects and use by educational, charitable and public-interest
  organisations are permitted noncommercial purposes. Commercial use is not
  granted by this license.
- **Brand and design:** the name "Poplex", the logo, wordmark, app icon and the
  visual design are **all rights reserved**.
- **Third-party materials** (fonts, Swift packages, photographs) keep their own
  terms — see [NOTICE](NOTICE).

## Contributing and security

This project does not accept code contributions; **issues are welcome**. See
[CONTRIBUTING.md](CONTRIBUTING.md). To report a vulnerability, follow
[SECURITY.md](SECURITY.md) instead of opening a public issue.

## Screenshots

App Store screenshots (iPhone, English interface).

<p align="center">
  <img src="docs/screenshots/01-cover.jpg" alt="Poplex: Build your language from work & life" width="19%">
  <img src="docs/screenshots/02-ask.jpg" alt="Ask what you're curious about: word and sentence cards" width="19%">
  <img src="docs/screenshots/03-snap.jpg" alt="Snap it, type it: a photo turned into a bilingual sentence card" width="19%">
  <img src="docs/screenshots/04-words.jpg" alt="Your words, sorted by topic in the Library" width="19%">
  <img src="docs/screenshots/05-scenes.jpg" alt="Your life, sorted into scenes: topic cards in the Library" width="19%">
</p>
