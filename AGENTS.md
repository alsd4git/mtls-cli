# Contribution workflow

## Branches and pull requests

- `main` is the integration branch. Start work from its latest remote state.
- Keep one active branch per issue or coherent task. Avoid unrelated changes.
- After another branch merges, rebase the next work branch onto updated `main` and rerun the affected tests.
- Pushes and merges require maintainer authorization, which may cover an agreed workflow. Verify the intended repository and remote before pushing.
- Direct pushes to `main` are allowed only when explicitly authorized. Keep them linear and fast-forward; never force-push `main`.
- Rewriting a published work branch requires approval. Use `--force-with-lease`, never an unrestricted force push.
- PRs should explain why, what changed, how it was tested, and link the issue when applicable.
- When automatic review is configured, wait for its first outcome and address findings. Do not request additional or manual reviews unless asked.
- Squash-merge PRs. Verify integration before deleting their remote and local branches. Never delete unmerged work without approval.

## Implementation and validation

- Follow existing architecture, conventions and pinned dependencies.
- Preserve unrelated local changes. Do not expose credentials or sensitive data.
- Run focused tests first, then broader checks appropriate to the risk. Use the commands documented by this repository.
- Prefer local validation and avoid duplicate CI runs. Do not claim tests passed when they were skipped or could not run.
- Report remaining risks and update related issues after integration.
- Documentation-only changes normally need a diff/link check, not a full application build.

## Project checks and safety

Use the repository's documented dependency setup and pinned tooling, then run the affected checks:

```sh
shellcheck ./*.sh ./lib/*.sh ./tests/*.sh
./tests/run.sh
```

- Use fixture CAs, test keys and temporary stores. Never issue/revoke real certificates, expose private keys or send certificate packages without authorization.
