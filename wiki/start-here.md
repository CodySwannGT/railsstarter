# Start here — Railsstarter Engineering Wiki

## Purpose
Durable, cited engineering knowledge for CodySwannGT/railsstarter: Rails 8.1, four physical MySQL databases, local TCP configuration, native schema ownership, main-only integration, explicit setup/renaming and disposable consumer validation, and the separation of credential-free image construction from optional asset publication and deployment. Source descriptions remain distinct from independently observed runtime evidence.

## What this is
A git-native LLM Wiki owned by **CodySwannGT** and maintained by the `lisa-wiki` kernel. It is the
durable home for this project's knowledge (and documentation). Sanitized source notes are preserved under
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

## Onboarding

Follow the [README setup checklist](../README.md) and [setup and contribution playbook](playbooks/onboarding.md). They cover explicit renaming, locked tools, host TCP/MySQL, shared-image startup, disposable offline worker validation and main-only contributions. The smoke runner's installed-wrapper receipt and real work-item/provider hook verification are separate checks. Independent walkthrough evidence and wiki verification accompany delivery; source descriptions alone do not establish runtime success.
