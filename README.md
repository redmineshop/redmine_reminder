# Redmine Reminder

**Last maintained: 2026-09-17**

[![CI](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml/badge.svg)](https://github.com/redmineshop/redmine_reminder/actions/workflows/ci.yml)
[![Community · Free · MIT](https://img.shields.io/badge/Community-Free%20%7C%20MIT-brightgreen)](LICENSE.md)
[![GitHub](https://img.shields.io/badge/source-GitHub-black)](https://github.com/redmineshop/redmine_reminder)

**Community / Free / MIT.** Use, copy, and modify this plugin at no cost. There is no paid edition and no signup required.

Schedule recurring reminders for Redmine projects and deliver them as Slack or Google Chat webhook notifications. Issue and wiki events can also be posted to the same channels.

This is the canonical source: [github.com/redmineshop/redmine_reminder](https://github.com/redmineshop/redmine_reminder).

Learn more about the Community plugin on [redmineshop.com](https://redmineshop.com) (overview only — install from GitHub, not from a storefront download).

## Features

- Create reminders for any Redmine project
- Schedule for a specific date/time or recur (daily, weekdays, weekly, custom days)
- Link reminders to specific Redmine issues in the same project
- Send notifications to a Slack incoming webhook and/or a Google Chat space webhook
- Per-project notification settings (channel, icon, username override via custom fields)
- Project module toggle — enable only on relevant projects
- `view_reminders` / `manage_reminders` role permissions
- Multi-language: English, Vietnamese, Japanese

## Compatibility

The plugin **declares** Redmine 5.0 or higher (`requires_redmine version_or_higher: '5.0'` in `init.rb`). This maintenance pass did **not** boot a live Redmine instance, so versions below are intent plus static checks — not a certified matrix.

| Component | Declared / intended | Verified in this repository (2026-09-17) |
| --- | --- | --- |
| Redmine | 5.0+ (written for 5.x; 6.x is intended but not integration-tested here) | Not boot-tested against a running Redmine |
| Ruby | 3.0+ on the Ruby versions your Redmine already supports | CI syntax-checks every `.rb` file on **Ruby 3.2** |
| Rails | Whatever the host Redmine ships (Rails 6.1 on 5.x, Rails 7.2 on 6.x) | Not integration-tested |

Use the Ruby version required by **your** Redmine (see [RedmineInstall](https://www.redmine.org/projects/redmine/wiki/RedmineInstall)). Example: Redmine 5.0 does not list Ruby 3.2; Redmine 6.0 lists Ruby 3.1–3.3.

## Installation (GitHub-first)

Clone this repository into Redmine's `plugins/` directory (folder name must stay `redmine_reminder`):

```bash
cd /path/to/redmine/plugins
git clone https://github.com/redmineshop/redmine_reminder.git
cd /path/to/redmine
bundle install
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

Restart Redmine after migrate.

`bundle install` is required because the plugin depends on the `httpclient` gem.

## Configuration

1. Administration → Plugins → Redmine Reminder → Configure
2. Set a Slack incoming webhook URL and/or a Google Chat space webhook URL (HTTPS only; private/loopback targets are ignored)
3. Enable the **Reminders** module on each project (Project Settings → Modules)
4. Optional: project custom fields named `Slack URL`, `Slack Channel`, and `Google Chat Webhook` to override the plugin defaults per project

Webhook URLs are secrets. Store them in Redmine settings or project custom fields, not in this git repository.

## Cron setup (recurring reminders)

Dispatch due reminders every 15 minutes (or more often if you need minute-level accuracy):

```cron
*/15 * * * * cd /path/to/redmine && bundle exec rake redmine:reminders:send RAILS_ENV=production
```

Equivalent task name: `redmine_reminder:send_reminders`. A helper script lives at `bin/cron_reminder.sh`.

## Troubleshooting

Open an issue on this repository: [GitHub Issues](https://github.com/redmineshop/redmine_reminder/issues).

Do not paste webhook URLs or tokens in issues — rotate them if they leak.

## Security notes

- Related issues on a reminder must belong to the same project and be visible to the current user.
- Outbound webhooks must be HTTPS and are blocked for loopback, link-local, and RFC1918 destinations. HTTP redirects are not followed.
- Scheduled reminders send to Slack and/or Google Chat when those webhooks are configured.

## License

MIT — see [LICENSE.md](LICENSE.md). Community and free forever; based on [sciyoshi/redmine-slack](https://github.com/sciyoshi/redmine-slack).

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
