# Changelog — Redmine Reminder

All notable changes to this plugin. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.0.1] — 2026-09-17

Maintenance review of the public Community plugin (GitHub-first docs, CI, and security hardening).

### Security

- Reject non-HTTPS and private/loopback/link-local webhook URLs; do not follow HTTP redirects
- Restrict related `issue_id` to issues in the current project (and visible to the user on write)
- Escape wiki page titles and custom-field values in Slack/Google Chat payloads
- Stop logging full webhook URLs (host only)

### Added

- Standalone webhook URL tests in CI (Ruby 3.2, no Redmine boot required)
- Rake alias `redmine:reminders:send` for the documented cron task

### Fixed

- Plugin settings default key is `slack_url` (the form and listener already used this name)
- Custom weekday checkboxes restore previously selected days
- Scheduled reminders also send to Slack when a Slack webhook is configured (previously Google Chat only)
- Manage/edit/delete links are shown only when the user has `manage_reminders`
- Hardcoded Vietnamese labels on the reminder show page now use core i18n keys

### Changed

- Plugin homepage / author URL point at this GitHub repository
- README is GitHub-first: clone install, honest compatibility table, Community / Free / MIT

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
- `requires_redmine` bumped to Redmine 5.0+ (from 0.8.0 legacy constraint)
- Frozen string literals on `init.rb`

[1.0.1]: https://github.com/redmineshop/redmine_reminder/releases/tag/v1.0.1
[1.0.0]: https://github.com/redmineshop/redmine_reminder/releases/tag/v1.0.0
