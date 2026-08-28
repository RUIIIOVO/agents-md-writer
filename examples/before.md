---
title: Project Rules
updated: 2026-08-28
---

# Project Rules

This file describes how the AI assistant should work in this repository. It is
maintained by the team and should be kept up to date. Please read it carefully
before making any changes to the codebase.

## About This Document

This document only describes *how* to work, not *what* to build. Product
requirements live elsewhere. If you are unsure about anything in this file, ask
the maintainer before proceeding.

## General Principles

- Write clean, maintainable, production-quality code.
- Follow the existing code style of the project.
- Be mindful of test coverage.
- Do not introduce breaking changes without discussion.
- Always think carefully before making changes.
- Use appropriate error handling.
- Consider performance implications.

## Setup

The project lives in /Users/alice/dev/acme-api. Clone it and run the setup
script. You will need Node and a database. Ask the team for credentials.

Start the dev server with the usual command. Tests can be run with the test
runner. Linting is handled by ESLint.

## Architecture

The code is organised into modules. Business logic goes in the service layer,
and database access goes in the repository layer. Controllers should be thin.

See docs/architecture.md for the full picture. Also read docs/onboarding.md,
docs/deployment.md, docs/style-guide.md and the wiki.

## Current Sprint

We are migrating from REST to GraphQL this quarter. Focus on the user service
first. The deadline is end of Q3.

## Review Checklist

- [ ] Code is well written
- [ ] Do not commit secrets
- [ ] Do not modify the vendor directory
- [ ] Tests pass
- [ ] The UI looks correct
