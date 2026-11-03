# Changelog

## [0.1.0] - 2026-11-03

### Added

- **production**: configure the production infrastructure (`bc1a2b6`)
- **production**: keep the stored plans for seven days (`e53a3db`)

### Upstream: infra (v∅ → v0.1.0)

- feat(infra): add the terragrunt root and the vps unit (46d6a42)
- docs(infra): describe the layout of the infra directory (e296e1f)
- feat(bootstrap): add the state storage unit and its script (524c8b8)
- chore(infra): add a makefile running the module checks (330cba5)
- chore(infra): add make targets generating the module docs (07ff644)
- docs(infra): document the infra directory (e665e93)
- docs(infra): document the retention of the stored plans (672643d)

### Upstream: module-vps (v∅ → v0.1.0)

- feat(vps): add the vps module (8995895)
- test(vps): test the vps module offline (4131ea9)
- docs(vps): document the vps module (1fd728b)
