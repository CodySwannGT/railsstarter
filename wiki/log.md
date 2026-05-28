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
