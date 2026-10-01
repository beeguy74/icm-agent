# icm-agent

A Claude Code skill for delegating a review or QA pass to an isolated subagent. The main agent builds an ICM (Interpretable Context Methodology) workspace — numbered Markdown files the subagent reads in order — fills it from what it knows, waits for your OK, launches the reviewer, and relays the report from disk.

| Layer | File | What it holds |
|---|---|---|
| 0 | `00_system.md` | Global rules: where to read input, where to write output, what to do when input is missing |
| 1 | `01_project.md` | The project under review |
| 2 | `02_persona.md` | The reviewer persona |
| 3 | `03_task_execution.md` | The steps and the severity scale |
| 4 | `04_workspace/input/`, `output/` | Inputs (a manifest of absolute paths, plus material that exists only in the conversation) and the report |

## Roles

| Target | Role | Report |
|---|---|---|
| a test suite | `test-suite-review` | `test_suite_review.md` |
| any other artifact: code change, plan, spec, config, prompt | `devils-advocate` | `da_review.md` |
| a running app, against test cases | `live-app-qa` | `test_report.md` |

## Layout

```
icm-agent/            the skill (what ~/.claude/skills/icm-agent links to)
  SKILL.md            role routing + workflow for the main agent
  icm-init.sh         creates <repo>/.icm/<role>-<timestamp>/ and prints its path
  icm-check.sh        pre-launch gate: placeholders, missing paths
  icm-guard.sh        save/check content hashes of dirty files around the reviewer run
  core/               layer 0 + launch prompt shared by all roles
  roles/<role>/       layers 1-3, role rules, input templates
  tests/              script and pack tests
docs/superpowers/plans/   implementation plan
```

## Install

```bash
git clone https://github.com/beeguy74/icm-agent.git ~/icm-agent
ln -s ~/icm-agent/icm-agent ~/.claude/skills/icm-agent
```

Claude Code loads a personal skill folder that is a symlink, so `git pull` updates the installed skill.

## Tests

```bash
bash icm-agent/tests/test_icm.sh && bash icm-agent/tests/test_packs.sh
```

## Design notes

- **Manifest instead of copying files into `input/`.** The agent always reads the current files, the scope stays explicit, and large inputs cost nothing to "move". `input/` holds only material that exists nowhere on disk, such as a diff frozen at review time.
- **Manifest instead of symlinks.** Claude Code's search tools use ripgrep, which doesn't follow symlinks by default, so a symlinked `input/` can look empty to the agent.
- **Workdir inside the repo, ignored by itself.** `<repo>/.icm/.gitignore` contains `*`, so runs never end up in a commit and the repo's own `.gitignore` is untouched. Runs are kept for comparison; delete `<repo>/.icm` when done.
- **Weak spots are proven on copies.** Reviewers break code in a copy under `04_workspace/output/scratch/` and check whether any test notices. The real files stay untouched, and the scratch directory is deleted at the end.
- **Background or forked Claude Code sessions** are blocked from writing into a checkout that another session is using. To allow it for one repository, add `{ "worktree": { "bgIsolation": "none" } }` to that repository's `.claude/settings.json`.

## Credits

The workspace layout follows **Interpretable Context Methodology (ICM)**, introduced by Jake Van Clief and David McDermott in [*Interpretable Context Methodology: Folder Structure as Agent Architecture*](https://arxiv.org/abs/2603.16021) (arXiv:2603.16021v2, 2026, CC BY 4.0). ICM replaces agent-orchestration code with a folder hierarchy of numbered stages and plain Markdown files that deliver stage-specific context. This repository is an independent adaptation of that idea as a Claude Code skill, not affiliated with the authors: the numbered `00`–`04` files map the paper's layers onto a single reviewer subagent.

## License

[MIT](LICENSE)
