# Changelog

All notable changes to this component are documented here.

## [0.1.0] - 2026-11-03

### Added

- **production**: add production inventory (`2f9c038`)
- **production**: pin the collection used by the production deployment (`e398894`)
- **production**: configure the sysctl role (`8a629f3`)

### Upstream: collection (v∅ → v0.1.0)

- feat(collection): add galaxy collection metadata for goabonga.vps (f283c1f)
- build: leave the local development state out of the collection (1eb8dbb)
- chore: add multicz config for the collection (2d3e39a)
- feat(version): add role displaying the deployment version (9564f9b)
- feat(version): apply role in the site playbook (7ac78b6)
- chore: add collection install script (e20fc98)
- feat(sysctl): add role skeleton (6dd006b)
- feat(sysctl): validate parameters (5eaf9ef)
- feat(sysctl): persist parameters in a sysctl.d file (5b41be7)
- feat(sysctl): apply parameters at runtime (62794d7)
- feat(sysctl): verify running values and detect drift (27e6211)
- feat(sysctl): add strict mode (0461970)
- feat(sysctl): support check and diff modes (9a57d95)
- feat(sysctl): restore previous values when the application fails (767e228)
- feat(sysctl): add profiles with the security profile (56fd48d)
- feat(sysctl): add the network profile (c3a2c72)
- feat(sysctl): add the memory profile (7b0aa62)
- feat(sysctl): add the filesystem profile (7adb005)
- feat(sysctl): apply role in the site playbook (2eed142)
- build(collection): leave the infra directory out of the collection (01766fa)
