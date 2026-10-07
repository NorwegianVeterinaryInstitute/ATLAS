# Contributing to ATLAS

There are many ways to contribute to **ATLAS**. Some are quick (fixing typos, improving documentation, filing bug reports or feature requests), others take more time (answering questions, submitting pull requests with code changes). Help in any form is appreciated.

## Filing issues

If you believe you found a bug, post it to the [issue tracker](https://github.com/NorwegianVeterinaryInstitute/ATLAS/issues). Include only the code needed to reproduce the bug.

## Answering questions

Answering questions is a great way to help. Questions can be asked either via the issue tracker or under [discussions](https://github.com/NorwegianVeterinaryInstitute/ATLAS/discussions).

## Improving documentation

The documentation is published at <https://norwegianveterinaryinstitute.github.io/ATLAS/>. It is built with [Zensical](https://zensical.org) from the Markdown files in `docs/`, and deployed when changes are merged to `main`.

* **Script usage, flags and examples** live in the `show_help` function of each script in `scripts/`. The script pages include the output of `-h`, so edit the help text there, not in `docs/`. Use a quoted heredoc (`cat << 'EOF'`) so that `${VARS}` are printed literally.
* **Everything else about a script** (prerequisites, output, error messages) goes in `docs/scripts/<name>.md`, around the `--8<-- "help/<name>.txt"` line.
* **General pages** are the other `.md` files in `docs/`, and images go in `docs/img/`. Link between pages with relative paths to the `.md` files.
* **New pages** must be added to `nav` in `zensical.toml`. A new script needs its own page in `docs/scripts/` and a `-h` flag that works without a config file.

To preview the site locally (with [uv](https://docs.astral.sh/uv/)):

```bash
bash .github/scripts/gen_help.sh
uvx zensical serve
```

## Making pull requests

Before opening a pull request (PR), please file an issue and describe the problem in some detail. For an enhancement, explain how the change makes things better for users. For a bug fix, explain the bug and how the fix removes it. This upfront work opens a conversation that often leads to a better fix.

Once there is agreement that a PR would help, the following makes things go faster:

* Create a separate Git branch for each PR.
* Use a [Conventional Commits](https://www.conventionalcommits.org) PR title (e.g. `fix: ...`, `feat: ...`, `docs: ...`). Releases and `NEWS.md` are generated from these by release-please, so don't edit `NEWS.md` or `CHANGELOG.md` by hand.

## AI-assisted contributions

Contributions made with the help of AI coding assistants are welcome. We follow the spirit of the Linux kernel's [guidelines for AI coding assistants](https://docs.kernel.org/process/coding-assistants.html):

* The human submitting the PR is responsible for the contribution: review all AI-generated code, make sure it works and that you understand it.
* Disclose AI use in the PR description
* Attribute AI help in commit messages with an `Assisted-by:` trailer, for example `Assisted-by: Claude Opus 5.5 <noreply@anthropic.com>`. Do not use `Co-Authored-By:` or `Signed-off-by:` for AI tools; only humans can take authorship and certify a contribution.