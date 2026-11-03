# Security Policy

## Supported versions

Security fixes are applied to the `main` branch only.

## Reporting a vulnerability

**Please do not open a public issue.** Email **goabonga@pm.me** with a
description of the problem, the steps to reproduce it and, if you have one, a
suggested mitigation. PGP encryption is available on request.

You can expect an acknowledgement within **3 business days** and a written
answer, with a fix or a mitigation plan, before any public disclosure.

## Scope

This repository holds Ansible roles and playbooks that configure an OVH VPS.
Please report anything that could expose credentials, weaken the
configuration of the server or let someone run code on it.

Deployments run from GitHub Actions. The credentials they use (SSH key, host
key, personal access token, GPG key) live in GitHub secrets, scoped to the
`ansible-production-apply` and `ansible-production-plan` environments when they allow it. They are
never committed: report any trace of one in the history or in a log.

`main` and the `ansible/*` branches only accept signed commits, so a change is
traceable to a key. Report any commit that seems to bypass this.
