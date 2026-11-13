## User story (required)
<!-- Replace NN. Without this line env-tracking cannot move the story on the board. -->
Refs: code-corhuila/property-docs#NN


## What changes and why
<!-- One paragraph. The reviewer reads this before the diff. -->


## How it was tested
<!-- The tests that cover the change and the result of the CI workflow. -->


## Promotion trail (only for pull requests into `qa` or `main`)
<!-- List the original commits this pull request re-applies.
     Every commit must carry the line "(cherry picked from commit <sha>)". -->
-


## Checklist
- [ ] Meets the acceptance criteria of the user story
- [ ] Local validation passes (`nginx -t` and `tests/smoke.sh`)
- [ ] Under 400 changed lines, excluding tests and generated files
- [ ] Title follows Conventional Commits
- [ ] No secrets: only `.env.example` with names
- [ ] Routes match the routing table of `api-gateway.yaml`
- [ ] The gateway validates no token and holds no business rule: every service validates its own
- [ ] Into `qa` or `main`: every commit was re-applied with `git cherry-pick -x`
