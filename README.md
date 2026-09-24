# Redmine Reminder — Slack & Google Chat Notifications with Scheduled Reminders

[![Community · Free forever](https://img.shields.io/badge/Community-Free%20forever-brightgreen)](https://redmineshop.com/products/redmine-reminder)
[![Redmine 5.x/6.x](https://img.shields.io/badge/Redmine-5.x%20%7C%206.x-blue)](https://redmineshop.com/docs/compatibility)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)
[![CI](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml/badge.svg)](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml)

**Last maintained:** 2026-09-25

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

- Redmine 5.0.x or 6.x
- Ruby 3.0+
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

## Cron setup (recurring reminders)

Add to your cron to trigger reminder dispatch:

```cron
*/15 * * * * cd /path/to/redmine && bundle exec rake redmine_reminder:send_reminders RAILS_ENV=production
```

`rake redmine:reminders:send` runs the same task. `bin/cron_reminder.sh` calls `redmine_reminder:send_reminders`.

## Troubleshooting

See [docs/reminder-troubleshooting](https://redmineshop.com/docs/reminder-troubleshooting) or open an issue at [GitHub Issues](https://github.com/redmineshop/redmine_reminder/issues).

## Compatibility

| Redmine | Ruby | Database | Status |
|---------|------|----------|--------|
| 6.x     | 3.2+ | MySQL 8 / PostgreSQL | Targeted — **untested** (no published QA matrix) |
| 5.1.x   | 3.1+ | MySQL 8 / PostgreSQL | Targeted — **untested** |
| 5.0.x   | 3.0+ | MySQL 8 / PostgreSQL | Targeted — **untested** |

The plugin declares `requires_redmine version_or_higher: '5.0'`. Do not treat catalog versions as tested cells.

## Screenshots

Plugin settings. Webhook URL fields are masked. The channel in the shot is the fake name `#acme-portal` (display only; the harness does not save it).

![Reminder webhook settings](screenshots/reminder-settings.png)

New reminder on the sample project, linked to an issue, set to repeat weekly:

![Issue reminder with weekly recurrence](screenshots/reminder-issue.png)

![Reminders list](screenshots/reminders-list.png)

![Reminder details](screenshots/reminder-detail.png)

Screenshot refresh lives in the private `redmineshop/redmineshop` harness. A public clone cannot run it.

## Tests

MiniTest lives under `test/` (unit + functional). It covers Reminder validations/schedule, `RemindersController` `#index` / `#show` / `#create` / `#edit` / `#update` / `#destroy`, cron dispatch (`RedmineReminder::ReminderService.process_reminders` plus rake `redmine_reminder:send_reminders` and alias `redmine:reminders:send`), and Slack / Google Chat webhook POST with `HTTPClient` stubbed. There is no live Slack or Google Chat call in this suite.

Public CI (`.github/workflows/ci.yml`) is still Ruby syntax only (`ruby -c`). A green badge does not run MiniTest and is not a Redmine compatibility result. This plugin is **not** shippable on that badge alone.

On a Redmine install that already has this plugin migrated:

```bash
bundle exec rake redmine:plugins:test NAME=redmine_reminder RAILS_ENV=test
```

On the private `redmineshop/redmineshop` demo stack (not this public clone):

```bash
PLUGIN_NAME=redmine_reminder ./demo/scripts/run-sso-plugin-tests.sh
```

### Quality harness (demo + E2E)

E2E lives in the **private** `redmineshop/redmineshop` harness (`docker-compose.demo.yml` + Playwright). This public GitHub repo is the plugin only — it does not ship that compose file, and a public clone cannot open private harness docs.

Install and smoke this plugin on your own Redmine: [reminder install](https://redmineshop.com/docs/reminder-install).

| Bar | Status |
| --- | --- |
| Automated tests beyond `ruby -c` | **MiniTest in this repo** — validations/schedule, controller CRUD including edit/update/destroy, cron dispatch, stubbed Slack/Google Chat POST. Public CI does not run that suite |
| Installed + enabled on demo Redmine | **Verified** — mounted via `demo/plugins/` on the private monorepo demo stack; seed enables the Reminders module on `plugin-qa` |
| E2E primary happy path | **Not re-run** — Playwright spec still covers open, create, and view. Evidence for this date is MiniTest |
| UI screenshot in README | **Unchanged** — `screenshots/{reminder-settings,reminder-issue,reminders-list,reminder-detail}.png` were not regenerated. `reminder-new-form.png` is the same image as `reminder-issue.png`. There is no Slack client in this harness, so `slack-example.png` is not shipped. |
| Redmine 5.1 / 6.x matrix | **Declared / untested** — MiniTest for this pass ran on one demo image (Redmine 7.0.1, Ruby 4.0.7, MySQL 8). That is not a 5.x or 6.x cell, and PostgreSQL was not run |

## License

MIT — see [LICENSE.md](LICENSE.md). Based on [sciyoshi/redmine-slack](https://github.com/sciyoshi/redmine-slack).
