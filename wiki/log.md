# Railsstarter Engineering Wiki — Log

> Append-only. One row per operation. Operations:
> `INIT, SETUP, INGEST, CREATE, UPDATE, MERGE, DEPRECATE, LINT, QUERY, REBUILD-INDEX`.

| Date | Operation | Target | Notes |
|---|---|---|---|
| 2026-05-28 | SETUP | wiki/ | Initialized Railsstarter Engineering Wiki with the lisa-wiki kernel. |
| 2026-05-28 | INGEST | sources/git/2026-05-28-railsstarter-git.md | git connector: 40 commits, HEAD 03eb89c, latest PR #47. |
| 2026-05-28 | INGEST | sources/docs/2026-05-28-project-rules.md | docs connector: .claude/rules/PROJECT_RULES.md (engineering handbook). |
| 2026-05-28 | CREATE | architecture/, playbooks/, projects/ | Synthesized 6 pages from the git + docs source notes. |
| 2026-05-28 | REBUILD-INDEX | index.md | Added Architecture/Playbooks/Projects sections and Sources entries. |
| 2026-05-28 | INGEST | sources/roles/2026-05-28-roles.md | roles connector: 7 roles, 7 staff pages (full ingest, first run for roles). |
| 2026-05-28 | INGEST | sources/git/2026-05-28-railsstarter-git.md | git connector refresh: HEAD 869e8dd, latest PR #48 (Lisa 2.116.0 + wiki bootstrap). |
| 2026-05-28 | CREATE | people/staff-roster.md | Synthesized the digital staff roster from the roles source note. |
| 2026-05-28 | REBUILD-INDEX | index.md | Added People section and sources/roles/ entry. |
