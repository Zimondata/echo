# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Echo is a Telegram-based AI personal assistant that helps users manage their diary entries, ideas, and plans through voice and text input. It uses OpenAI's GPT-4 for content analysis and Whisper for speech-to-text transcription.

**Tech Stack:**
- Ruby 3.4.5
- Rails 8.0.3
- PostgreSQL 17 with pgvector extension
- Solid Queue (background jobs, with Sidekiq available as alternative)
- Telegram Bot API
- OpenAI API (GPT-4, Whisper)

## Common Development Commands

### Running the Application

```bash
# Start the server
bin/dev
# or
bin/rails server

# Rails console
bin/rails console

# Run tests
bin/rails test

# Run specific test file
bin/rails test test/models/user_test.rb

# Run specific test case
bin/rails test test/models/user_test.rb:10

# Code quality check
bin/rubocop

# Auto-fix rubocop issues
bin/rubocop -a

# Security scan
bin/brakeman
```

### Database Commands

```bash
# Create database
bin/rails db:create

# Run migrations
bin/rails db:migrate

# Rollback last migration
bin/rails db:rollback

# Reset database (drop, create, migrate, seed)
bin/rails db:reset

# View database schema
cat db/schema.rb
```

### Background Jobs

```bash
# Monitor background jobs
bin/jobs

# View job queue status in console
bin/rails console
> SolidQueue::Job.count
> SolidQueue::Job.pending.count
```

### Telegram Webhook Commands

```bash
# Set webhook (replace with your bot token and ngrok URL)
curl -X POST "https://api.telegram.org/bot<BOT_TOKEN>/setWebhook" \
  -d "url=<NGROK_URL>/telegram/webhook"

# Check webhook status
curl "https://api.telegram.org/bot<BOT_TOKEN>/getWebhookInfo"

# Delete webhook
curl "https://api.telegram.org/bot<BOT_TOKEN>/deleteWebhook"
```

### Useful Rails Console Commands

```ruby
# Get first user and their entries
User.first.entries.recent

# Create test reminder
Reminder.create!(
  user: User.first,
  reminder_type: "one_time",
  remind_at: 5.minutes.from_now,
  message: "Test reminder"
)

# Check pending reminders
Reminder.pending.where("remind_at <= ?", Time.current)

# Test vector similarity search
entry = Entry.first
entry.nearest_neighbors(:embedding, distance: "cosine").first(5)
```

## Architecture Overview

### Request Flow

1. **Telegram Message → Webhook**
   - Telegram sends message to `/telegram/webhook` endpoint
   - `TelegramController#webhook` receives the update
   - Immediately queues `TelegramWebhookJob` and returns 200 OK

2. **Async Processing**
   - `TelegramWebhookJob` processes the message in background
   - Creates or finds `User` based on `telegram_id`
   - Delegates to `Telegram::MessageHandler`

3. **Message Handling**
   - `Telegram::MessageHandler` routes based on message type:
     - Commands (`/start`, `/help`, etc.) → command handlers
     - Voice messages → `Ai::WhisperService` (transcription) → content processing
     - Text messages → content processing directly

4. **Content Processing**
   - `Ai::ContentAnalyzer` analyzes text with GPT-4
   - Determines entry type: `diary`, `idea`, `plan`, or `plan_update`
   - Extracts metadata: dates, priorities, tags
   - Creates `Entry` record
   - Optionally creates `CalendarEvent` and/or `Reminder`

5. **Reminders**
   - `SendRemindersJob` runs every minute (cron-scheduled)
   - Finds pending reminders where `remind_at <= Time.current`
   - Sends Telegram message via `Telegram::BotService`
   - Marks reminder as `sent`

### Key Service Objects

**`Telegram::BotService`**
- Singleton service for Telegram API interactions
- Methods: `send_message`, `send_typing`, `download_file`
- Handles API errors gracefully

**`Telegram::MessageHandler`**
- Orchestrates message processing
- Handles commands and content processing
- Creates entries, events, and reminders

**`Ai::WhisperService`**
- Transcribes audio files using OpenAI Whisper API
- Creates temporary files for audio processing
- Default language: Russian (`ru`)

**`Ai::ContentAnalyzer`**
- Analyzes text content using GPT-4 mini
- Returns structured JSON with entry type, summary, dates, etc.
- System prompt defines four entry types and expected response format

### Data Models

**`User`**
- Represents Telegram user
- Key fields: `telegram_id` (unique), `timezone`, `language`
- Google OAuth fields: `google_refresh_token`, `google_access_token`
- Has many: `entries`, `calendar_events`, `reminders`

**`Entry`**
- Core model for all user content
- Types: `diary`, `idea`, `plan`, `plan_update`
- Has `embedding` vector column (1536 dimensions) for similarity search
- Includes: `content`, `transcript`, `audio_file_id`, `metadata` (jsonb)
- Uses `neighbor` gem for vector search with `has_neighbors :embedding`

**`CalendarEvent`**
- Linked to `Entry` and `User`
- Fields: `title`, `description`, `start_time`, `end_time`
- `google_event_id` for future Google Calendar sync

**`Reminder`**
- Linked to `Entry` and `User`
- Types: `one_time`, `recurring`
- Status: `pending`, `sent`, `cancelled`
- `remind_at` determines when to send

## Important Patterns

### Error Handling
- Always return 200 OK to Telegram webhook (prevents retries)
- Log errors but don't expose them to Telegram
- Graceful fallbacks in AI services (return default analysis if API fails)

### Async Processing
- All webhook processing is asynchronous via Solid Queue
- Never block webhook response
- Use `perform_later` for background jobs

### Environment Variables
- Required: `TELEGRAM_BOT_TOKEN`, `OPENAI_API_KEY`
- Optional: Google OAuth credentials (for future feature)
- Managed via `dotenv-rails` gem

### Vector Embeddings
- Entry model has `embedding` field (vector, limit: 1536)
- Uses pgvector extension with IVFFlat index
- Cosine distance for similarity search
- Access via `entry.nearest_neighbors(:embedding, distance: "cosine")`

## Testing Strategy

- Minitest framework (Rails default)
- Test files mirror app structure: `test/models/`, `test/controllers/`, `test/jobs/`
- Run individual test: `bin/rails test path/to/test_file.rb:line_number`

## Development Workflow

### Adding New Features

1. Create migration if database changes needed
2. Update models with validations and associations
3. Add service logic in `app/services/`
4. Update message handler if new commands/behaviors
5. Add tests
6. Run `bin/rubocop` to check code style

### Debugging

1. Check logs: `tail -f log/development.log`
2. Use Rails console: `bin/rails console`
3. Verify webhook status with curl command
4. Test AI services in isolation via console

### Local Development with ngrok

- ngrok required for webhook testing (Telegram requires HTTPS)
- Start ngrok: `ngrok http 3000`
- Update webhook URL when ngrok restarts (URL changes)
- Can use `localhost` testing via Telegram Bot API long polling (not recommended)

## Future Integration Notes

### Google Calendar (Planned)
- OAuth flow to be implemented
- Store tokens in User model (fields already exist)
- Sync CalendarEvent records with Google Calendar
- Handle token refresh

### Vector Search (Infrastructure Ready)
- pgvector extension enabled
- Embedding column exists on Entry model
- Need to generate embeddings when creating entries
- Use OpenAI embeddings API or similar

## Critical Configuration Files

- `config/initializers/telegram_bot.rb` - Telegram bot configuration
- `config/initializers/openai.rb` - OpenAI client configuration
- `.env` - Environment variables (not in git)
- `config/routes.rb` - Single webhook route: `POST /telegram/webhook`

## Language and Localization

- Primary language: Russian (ru)
- All user-facing messages in Russian
- AI prompts in Russian
- Timezone support via User model (`timezone` field, default: "UTC")

## Job Scheduling

- `SendRemindersJob` runs every minute (configured via Solid Queue)
- Processes reminders where `remind_at <= Time.current` and `status = 'pending'`
- Updates reminder status to `sent` after sending

## Security Considerations

- CSRF protection skipped on webhook endpoint (`skip_before_action :verify_authenticity_token`)
- API keys stored in environment variables
- Never commit `.env` file
- PostgreSQL accessible only locally in development
- Production deployment via Kamal (Docker-based)
