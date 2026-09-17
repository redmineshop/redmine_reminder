# Redmine Reminder — Slack & Google Chat Notifications with Scheduled Reminders

[![Community · Free forever](https://img.shields.io/badge/Community-Free%20forever-brightgreen)](https://redmineshop.com/products/redmine-reminder)
[![Redmine 5.x/6.x](https://img.shields.io/badge/Redmine-5.x%20%7C%206.x-blue)](https://redmineshop.com/docs/compatibility)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow)](LICENSE.md)

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
*/15 * * * * cd /path/to/redmine && bundle exec rake redmine:reminders:send RAILS_ENV=production
```

## Troubleshooting

See [docs/reminder-troubleshooting](https://redmineshop.com/docs/reminder-troubleshooting) or open an issue at [GitHub Issues](https://github.com/redmineshop/redmine_reminder/issues).

## Compatibility

| Redmine | Ruby | Database | Status |
|---------|------|----------|--------|
| 6.x     | 3.2+ | MySQL 8 / PostgreSQL | Targeted — **untested** (no published QA matrix) |
| 5.1.x   | 3.1+ | MySQL 8 / PostgreSQL | Targeted — **untested** |
| 5.0.x   | 3.0+ | MySQL 8 / PostgreSQL | Targeted — **untested** |

The plugin declares `requires_redmine version_or_higher: '5.0'`. Do not treat catalog versions as tested cells.

## Screenshot

Reminders index on a project (demo Redmine, plugin quality harness):

![Reminders list](screenshots/reminders-list.png)

Create form and detail view: [screenshots/reminder-new-form.png](screenshots/reminder-new-form.png), [screenshots/reminder-detail.png](screenshots/reminder-detail.png).

Refresh from the RedmineShop monorepo: `./demo/scripts/run-plugin-e2e.sh`.

## Tests

This plugin does not yet ship `test/unit` / `test/functional` in-tree. The quality bar for Community plugins is met via the demo harness (E2E), not `ruby -c` alone.

### Quality harness (demo + E2E)

| Bar | Status |
| --- | --- |
| Automated tests beyond `ruby -c` | **Partial** — Playwright E2E verified on demo Redmine; plugin MiniTest `test/` suite not yet added |
| Installed + enabled on demo Redmine | **Verified** — mounted via `demo/plugins/` on `docker-compose.demo.yml`; `demo/scripts/prepare-demo-harness.sh` migrates + seeds `plugin-qa` with the Reminders module |
| E2E primary happy path | **Verified** — Playwright `demo/e2e/tests/redmine_reminder.spec.js` (open UI, create, view) on the demo stack |
| UI screenshot in README | **Verified** — `screenshots/{reminder-new-form,reminders-list,reminder-detail}.png` from that spec |
| Redmine 5.1 / 6.x matrix | **Declared / untested** — this harness is one demo image, not a QA matrix |

How to run: [docs/plugin-quality-harness.md](../../../../docs/plugin-quality-harness.md).

## License

MIT — see [LICENSE.md](LICENSE.md). Based on [sciyoshi/redmine-slack](https://github.com/sciyoshi/redmine-slack).
