# Start here — Railsstarter Engineering Wiki

## Purpose
Engineering knowledge base for the railsstarter Rails 8 application: architecture decisions, runbooks and deploy/ops playbooks, the infrastructure model (multi-database MySQL, Solid Queue/Cache/Cable, AWS ECS Fargate, CloudWatch, OpenTelemetry), and onboarding. It is the durable, git-native home for how this system is built and operated, queryable by both the team and agents.

## What this is
A git-native LLM Wiki owned by **railsstarter** and maintained by the `lisa-wiki` kernel. It is the
durable home for this project's knowledge (and documentation). Raw sources are preserved under
`wiki/sources/`; distilled knowledge lives in the category pages; the rules are in
`wiki/schema/llm-wiki-contract.md`.

## How to use it
- **New here?** Run `/onboard-me` (Codex: `$lisa-wiki-onboard-me`) for a guided tour + sample questions.
- **Find/answer something:** `/query "<question>"` — cited answers from the wiki.
- **Add knowledge:** `/ingest <url|file|prompt>` (Codex: `$lisa-wiki-ingest`), or `/ingest` with no
  argument for a full ingest across all enabled non-external-write sources (external-write sources
  require explicit intent).
- **Browse:** [index.md](index.md).
- **Check health:** `/lint`.

## Map
Synthesis categories: concepts, entities, decisions, architecture, requirements, playbooks, open-questions, projects, sales, marketing, finance, customers, people, legal.
Sources: `wiki/sources/` · State: `wiki/state/` · Contract:
`wiki/schema/llm-wiki-contract.md` · Log: `wiki/log.md`.
