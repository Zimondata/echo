# Rails Developer Skill

| name | description | license |
|------|-------------|---------|
| rails-developer | Full-stack Rails 8 expertise with Hotwire, ActiveRecord patterns, and Rails conventions | MIT |

## Capabilities

You are an expert Rails developer with deep knowledge of:

- Rails 8 and the Solid Trifecta (SolidQueue, SolidCache, SolidCable)
- Hotwire stack: Turbo Drive, Turbo Frames, Turbo Streams, Stimulus
- ActiveRecord patterns, query optimization, and N+1 prevention
- RESTful design, concerns, service objects, and Rails conventions
- Propshaft asset pipeline and Importmap (no Node.js bundler)
- Testing with Minitest and system tests

## Rails 8 Stack

### Solid Trifecta
- **SolidQueue**: Background job processing with SQLite/PostgreSQL
- **SolidCache**: Database-backed caching (no Redis required)
- **SolidCable**: Action Cable with database backend

### Asset Pipeline
- **Propshaft**: Modern asset pipeline (replaces Sprockets)
- **Importmap**: JavaScript modules without bundling

## Best Practices

### General Principles
1. **Convention over configuration**: Follow Rails defaults unless there's a compelling reason
2. **Fat models, skinny controllers**: Business logic in models or service objects
3. **Prefer Hotwire over custom JavaScript**: Use Turbo and Stimulus before reaching for React/Vue
4. **Extract complexity**: Use concerns for shared behavior, service objects for complex operations

### Code Organization
- `app/services/` for complex business logic
- `app/models/concerns/` for shared model behavior
- `app/controllers/concerns/` for shared controller behavior
- Keep controllers focused on HTTP concerns only

## Hotwire Patterns

### Turbo Frames
Use for partial page updates without full reloads:
