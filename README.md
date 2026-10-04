# Redmine Reminder — Slack & Google Chat Notifications with Scheduled Reminders

[![Community · Free forever](https://img.shields.io/badge/Community-Free%20forever-brightgreen)](https://redmineshop.com/products/redmine-reminder)
[![Redmine 7.0.1 verified](https://img.shields.io/badge/Redmine-7.0.1%20verified-blue)](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)
[![CI](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml/badge.svg)](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml)

**Last maintained:** 2026-10-04

**Source on GitHub:** [github.com/redmineshop/redmine_reminder](https://github.com/redmineshop/redmine_reminder)

Schedule recurring reminders for Redmine projects — delivered as Slack or Google Chat notifications. Set once, send on schedule, link to issues.

## Features

- Create reminders for any Redmine project
- Schedule for a specific date/time or recur (daily, weekdays, weekly, custom days)
- Link reminders to specific Redmine issues
- Send notifications to Slack webhook or Google Chat space webhook
- Per-project notification settings (channel, icon, username override)
- Project module toggle — enable only on relevant projects
- `view_reminders` / `manage_reminders` role permissions
- Multi-language: English, Vietnamese, Japanese

## Requirements

- Redmine 5.0 or newer (`requires_redmine version_or_higher: '5.0'`)
- Ruby is the version shipped with that Redmine release. Public CI uses the official `redmine:7.0.1` image
- A Slack incoming webhook URL or Google Chat space webhook URL

## Installation

Clone from GitHub, then migrate:

```bash
cd /path/to/redmine/plugins
git clone https://github.com/redmineshop/redmine_reminder.git
cd /path/to/redmine
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
# Restart your Redmine server
```

See the [install guide](https://redmineshop.com/docs/reminder-install) for full instructions.

## Configuration

1. Admin → Plugins → Redmine Reminder → Configure
2. Set your Slack or Google Chat webhook URL
3. Enable the "Reminders" module on each project (Project Settings → Modules)

Optional per-project overrides are project custom fields named `Slack URL`, `Slack Channel`, and `Google Chat Webhook`. The plugin saves `Slack URL` and `Google Chat Webhook` as administrator-only fields, so those URLs are not shown on the project overview or project settings to other users. Global webhook URLs stay on the plugin configuration page, which is administrator-only.

## Cron setup (recurring reminders)

Add to your cron to trigger reminder dispatch:

```cron
*/15 * * * * cd /path/to/redmine && bundle exec rake redmine_reminder:send_reminders RAILS_ENV=production
```

`rake redmine:reminders:send` runs the same task. `bin/cron_reminder.sh` calls `redmine_reminder:send_reminders`.

## Troubleshooting

See [docs/reminder-troubleshooting](https://redmineshop.com/docs/reminder-troubleshooting) or open an issue at [GitHub Issues](https://github.com/redmineshop/redmine_reminder/issues).

## Compatibility

`init.rb` sets `requires_redmine version_or_higher: '5.0'`, so 5.0 and newer are declared. Verified means public CI booted that Redmine version, installed this plugin, ran its migrations, and ran the MiniTest suite. MySQL and PostgreSQL are not part of that job. SQLite is what the official image uses in CI.

| Redmine | Declared | Verified |
|---------|----------|----------|
| 5.0.x   | Yes      | No |
| 5.1.x   | Yes      | No |
| 6.0.x   | Yes      | No |
| 6.1.x   | Yes      | No |
| 7.0.1   | Yes      | Yes — official `redmine:7.0.1` image (Ruby 4.0.7, Rails 8.1.3.1), SQLite, via `test/run-redmine-7.0.1.sh`: 90 runs, 292 assertions, 0 failures, 0 errors, 0 skips |

Other 7.0 patch releases were not run.

## Screenshots

Plugin settings. Webhook URL fields are masked. The channel in the shot is `#acme-portal`.

![Reminder webhook settings](screenshots/reminder-settings.png)

New reminder on the sample project, linked to an issue, set to repeat weekly:

![Issue reminder with weekly recurrence](screenshots/reminder-issue.png)

![Reminders list](screenshots/reminders-list.png)

![Reminder details](screenshots/reminder-detail.png)

## Tests

MiniTest lives under `test/`. It covers reminder validations and schedule selection, `RemindersController` index/show/new/create/edit/update/destroy (including permission checks, cross-project and private issue links, and CSRF), cron dispatch (`RedmineReminder::ReminderService.process_reminders`, rake `redmine_reminder:send_reminders`, and the `redmine:reminders:send` alias), and Slack / Google Chat payload building. HTTP is stubbed. The suite does not call Slack or Google Chat.

Public CI (`.github/workflows/ci.yml`) boots official `redmine:7.0.1`, installs this plugin, runs migrations, and runs that suite:

```bash
bash test/run-redmine-7.0.1.sh
```

On a Redmine install that already has this plugin migrated:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_reminder RAILS_ENV=test
```

This repository does not include a browser end-to-end run. The screenshots above were not regenerated for the 7.0.1 CI job. Install the plugin on your own Redmine with the steps in [Installation](#installation). Notes: [reminder install](https://redmineshop.com/docs/reminder-install).

## License

MIT — see [LICENSE.md](LICENSE.md). Based on [sciyoshi/redmine-slack](https://github.com/sciyoshi/redmine-slack).
