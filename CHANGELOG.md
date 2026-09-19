# Changelog — Redmine Reminder

All notable changes to this plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- MiniTest: Reminder validations/schedule (`test/unit/reminder_test.rb`) and RemindersController `#index` / `#create` / `#show` (`test/functional/reminders_controller_test.rb`). Still partial — no webhook POST, cron, or edit/update/destroy coverage.
- Plugin quality harness notes and README screenshot slots (demo Redmine E2E; not a Redmine version matrix)

### Changed

- README: **Last maintained** 2026-09-18, embed all three harness screenshots, honest MiniTest **Partial** table, and public-safe harness wording (no clickable private-monorepo URLs)

## [1.0.0] — 2026-07-19

First community release via RedmineShop. Based on [sciyoshi/redmine-slack](https://github.com/sciyoshi/redmine-slack) (MIT) and extended by HAPO / tuandbe.

### Added

- Scheduled and recurring reminders for Redmine projects (daily, weekdays, weekly, custom days)
- Link reminders to specific Redmine issues
- Send notifications to Slack webhooks and Google Chat spaces
- Per-project notification settings (channel, icon, username)
- Project module `reminders` with `view_reminders` / `manage_reminders` permissions
- Project menu entry "Reminder" for quick access
- Multi-language support: English, Vietnamese, Japanese
- Rake task `redmine:reminders:send` for cron-based delivery

### Changed

- Updated version constant to 1.0.0 (from upstream 0.4.0)
- Plugin registration now references RedmineShop storefront URL
- `requires_redmine` bumped to Redmine 5.0+ (from 0.8.0 legacy constraint)
- Frozen string literals on `init.rb`

[1.0.0]: https://github.com/tuandbe/redmine-slack/releases/tag/v1.0.0
