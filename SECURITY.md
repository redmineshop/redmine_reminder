# Security

This is a **Community / Free / MIT** plugin. Please do not open issues that contain Slack or Google Chat webhook URLs, tokens, or other secrets — rotate them if they were pasted anywhere.

## Reporting a vulnerability

Prefer a [GitHub Security Advisory](https://github.com/redmineshop/redmine_reminder/security/advisories/new) on this repository. If advisories are unavailable, open a [GitHub Issue](https://github.com/redmineshop/redmine_reminder/issues) **without** webhook URLs or credentials.

## What this plugin sends

Outbound HTTP(S) requests are made only to webhook URLs configured by a Redmine administrator (plugin settings) or by project custom fields named `Slack URL` / `Google Chat Webhook`. Delivery is skipped for non-HTTPS URLs and for loopback, link-local, or private-network destinations. Redirects are not followed.
