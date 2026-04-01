# Contributing to `rebar3_uncovered`

1. [License](#license)
1. [Reporting a Bug](#reporting-a-bug)
1. [Requesting or Implementing a Feature](#requesting-or-implementing-a-feature)
1. [Submitting Your Changes](#submitting-your-changes)
   1. [Code Style](#code-style)
   1. [Committing Your Changes](#committing-your-changes)
   1. [Pull Requests and Branching](#pull-requests-and-branching)
   1. [Credits](#credits)

## License

`rebar3_uncovered` is licensed under the [MIT License](LICENSE.md), for all code.

## Reporting a Bug

`rebar3_uncovered` is not perfect software and might have bugs.

Bugs can be reported via
[GitHub issues: bug report](https://github.com/eproxus/rebar3_uncovered/issues/new?template=bug_report.md).

Some contributors and maintainers may be unpaid developers working on `rebar3_uncovered`, in their
own time, with limited resources. We ask for respect and understanding, and will provide the same
back.

If your contribution is an actual bug fix, we ask you to include tests that, not only show the issue
is solved, but help prevent future regressions related to it.

## Requesting or Implementing a Feature

Before requesting or implementing a new feature, do the following:

- search, in existing [issues](https://github.com/eproxus/rebar3_uncovered/issues)
(open or closed), whether the feature might already be in the works, or has already been rejected,
- make sure you're using the latest software release (or even the latest code, if you're going for
_bleeding edge_).

If this is done, open up a
[GitHub issues: feature request](https://github.com/eproxus/rebar3_uncovered/issues/new?template=feature_request.md).

We may discuss details with you regarding the implementation, and its inclusion within the project.

We try to have as many of `rebar3_uncovered`'s features tested as possible. Everything that a user
can do, and is repeatable in any way, should be tested, to guarantee backwards compatible.

## Submitting Your Changes

### Code Style

- do not introduce trailing whitespace
- indentation is 4 spaces, not tabs
- try not to introduce lines longer than 100 characters
- write small functions whenever possible, and use descriptive names for functions and variables
- comment tricky or non-obvious decisions made to explain their rationale

### Committing Your Changes

Merging to the `main` branch will usually be preceded by a squash.

While it's Ok (and expected) your commit messages relate to why a given change was made, be aware
that the final commit (the merge one) will be the issue title, so it's important it is as specific
as possible. This will also help eventual automated changelog generation.

### Pull Requests and Branching

All fixes to `rebar3_uncovered` end up requiring a +1 from one or more of the project's
maintainers.

During the review process, you may be asked to correct or edit a few things before a final rebase
to merge things. Do send edits as individual commits to allow for gradual and partial reviews to be
done by reviewers.

### Credits

`rebar3_uncovered` has been improved by
[many contributors](https://github.com/eproxus/rebar3_uncovered/graphs/contributors)!
