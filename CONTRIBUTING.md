# Contributing (team workflow)

1. **Branch per module or feature.** `git checkout -b alu-shift-fix`.
2. **Open a pull request into `main`.** Fill in the PR template --
   in particular, paste what `make conformance` actually did.
3. **CI runs automatically:** lint and unit tests must pass (they
   gate the merge); conformance reports but does not gate on an
   ordinary PR.
4. **The module's owner reviews and approves.** Branch protection with
   "require review from code owners" enforces this from `.github/CODEOWNERS`
   -- if you're touching someone else's module, tag them explicitly.
5. **Merge.**

## Before your first push

```
./scripts/install_hooks.sh
```

This installs a pre-push hook that runs `make lint && make test`
before every push -- the same checks CI runs, on your own machine,
before you wait for a round trip to GitHub.

## At each milestone deadline

```
git tag m3          # or m4, m5, m6, final -- whichever is due
git push --tags
```

Grading always reads the tagged commit, not whatever is on `main` at
the moment someone looks. Pushing a milestone tag also flips the
conformance job from informational to authoritative for that ref (see
`.github/workflows/milestone.yml`).

## Keeping the bug log honest

Every bug gets an entry in `doc/bug_log_template.md` (or a GitHub
issue from `.github/ISSUE_TEMPLATE/bug_report.md`, later copied into
the log) with an honest `found by` field. This is graded, and it is
also the data your verification report's "unit tests are cheap,
integration bugs are expensive" argument depends on -- an empty or
after-the-fact bug log is easy to spot.
