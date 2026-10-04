# Changelog — Redmine Reminder

All notable changes to this plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Unreleased

### Added

- GitHub Actions boots official Redmine 7.0.1, migrates this plugin, and runs its MiniTest suite (`test/run-redmine-7.0.1.sh`).
- Tests for webhook HTTP errors and connection failures, CSRF on create/destroy, cross-project and private issue links, plugin-settings access, and webhook URL visibility.
- MiniTest for reminder schedule selection, RemindersController CRUD, cron dispatch, and stubbed Slack / Google Chat webhook POST.
- Rake alias `redmine:reminders:send` for `redmine_reminder:send_reminders`.

### Fixed

- Slack and Google Chat webhook URLs are redacted from logs and from `redmine_reminder:test_webhook` output.
- README cron example calls `redmine_reminder:send_reminders`, the task `bin/cron_reminder.sh` runs.
- Reminder detail uses locale strings for the created and last-updated labels.
- Project custom fields named `Slack URL` and `Google Chat Webhook` are saved as administrator-only, so the URL is not rendered to other users.
- A reminder can link only to an issue in the same project that the current user can see.
- Reminder index and detail pages show edit and delete only to users who can manage reminders.
- Custom weekday checkboxes stay checked when a reminder is edited.

### Changed

- README compatibility matrix: Redmine 7.0.1 is the verified cell. 5.0–6.1 stay declared and unverified.

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
