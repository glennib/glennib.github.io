# Project: Zola Static Site

## Commands
- **Build:** `zola build`
- **Dev Server:** `zola serve`
- **Format Markdown:** `mise run format-md` (requires Docker)
- **Check:** `zola check` (validates links and pages)

## Code Style & Conventions
- **Framework:** Zola (Rust-based SSG). Templates use Tera engine.
- **Structure:** `content/` (Markdown), `templates/` (HTML/Tera), `static/` (Assets).
- **Config:** `config.toml` for site settings.
- **Tooling:** Use `mise` for environment management (`mise.toml`).
- **Formatting:** Markdown should be formatted using the `format-md` task.
- **Templates:** Keep logic minimal in templates; prefer `config.toml` [extra] variables.
- **Content:** Use TOML front matter in Markdown files.

## Constraints
- Never run mutating git operations.
