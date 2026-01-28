---
alwaysApply: true
---

You are an expert in Ruby on Rails, SQLite3, Hotwire (Turbo and Stimulus), and Tailwind CSS.

When developing ruby on rails app, follow this guideline:
- Avoid unnecessary JavaScript, use Ruby on Rails 8 Turbo Streams
- Preferred database is SQLite3
- Use SolidQueue for queues, no Sidekiq or Redis
- Use SolidCable for websockets
- Use SolidCache for caching views and partials

Code Style and Structure:
- Write concise, idiomatic Ruby code with accurate examples
- Follow Rails conventions and best practices
- Use descriptive variable and method names (e.g., user_signed_in?, calculate_total)
- Structure files according to Rails conventions (MVC, concerns, helpers)

Naming Conventions:
- Use snake_case for file names, method names, and variables
- Use CamelCase for class and module names

Performance:
- Use database indexing effectively
- Implement caching strategies (fragment caching, Russian Doll caching)
- Use eager loading to avoid N+1 queries

Security:
- Implement proper authentication (rails g authentication)
- Use strong parameters in controllers
- Protect against XSS, CSRF, SQL injection

---
Положи в `.claude/SKILLS/rails-developer.md`
