# Project Overview

rebar3_uncovered is a Rebar 3 plugin that reports on uncovered lines from tests.

## Architecture

* `rebar3_uncovered` — Provider entry point: parses CLI opts, orchestrates the pipeline
* `rebar3_uncovered_cover` — Imports `.coverdata` files and extracts uncovered lines per module
* `rebar3_uncovered_git` — Filters uncovered lines by git diff (stub)
* `rebar3_uncovered_source` — Reads source files and groups uncovered lines into context regions
* `rebar3_uncovered_format` — Renders regions as human-readable or raw output

## Build & Development Commands

```sh
mise run --output=keep-order verify             # Run all linting
mise run format                                 # Format all code
elp lint --diagnostic-filter W0023 --apply-fix  # Apply a specific elp fix by code
```

## Coding Conventions

* Prefer exceptions over tagged return values. If the caller cannot meaningfully
  act on the return value at the call site, an exception should be used.
* Keep exported functions at the top under API heading
    * Sorted under relevant sections if needed
* Keep private functions below under the Internal heading
    * Here functions should be sorted in the order of appearance in the module

## Changes

Before making changes:

* Run tests with `mise run --output=keep-order test` and establish a code
  coverage baseline

When making changes:

* When refactoring, check if multiple lines can be joined and still stay under
  the length limit. When in doubt, prefer longer lines over shorter lines, the
  formatter will split them

After every change

* Format the code: `mise run format`
* Lint: `mise run --output=keep-order verify`
* Docs: `mise run docs`
* Test: `mise run --output=keep-order test`
* Ensure all modified code is covered by tests by reading the text files in
  `_build/test/cover/{eunit,aggregate}/*.txt`
* For substantial changes or new features, verify that coverage did not go down
  from the baseline
