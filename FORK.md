# Fork policy: no telemetry, no upstream traffic

This clone is `amitchhetri43/reverse-eng`, a fork of `morluto/rea`. It is the
only REA that runs on this machine. Two rules apply to it.

## 1. Nothing leaves the machine on its own

Upstream REA ships one automatic outbound call: the CLI framework `incur`
schedules a detached release check (`--incur-update-check`) at most once a day
and caches the answer under the user's cache directory. `rea update` performs a
second one: `npm view` for the latest version, then `npm install -g`.

Both are removed here.

- `src/cli.ts` creates the CLI with `update: false`. The framework documents
  this value as "disable automatic checks", and it also disables the detached
  child, the notice, and the `--update` installer.
- `src/cli/setupCommands.ts` no longer calls `runUpdate`. `rea update` now
  formats `src/application/ForkUpdate.ts`, which performs no I/O at all: it
  names the local clone and the manual steps.

There is no analytics or error-reporting SDK anywhere in the tree. The audited
`grep` for `posthog`, `sentry`, `mixpanel`, `amplitude`, `datadog`,
`opentelemetry`, `segment.io` and `googletagmanager` returns nothing outside
test fixtures that merely contain the words as strings.

Network paths that remain are all caller-initiated and never run at startup:

| Path | When it runs |
| --- | --- |
| `capture-browser-scenario`, `inspect-web-page`, `observe-web-session` | only when you name a page or endpoint |
| `environment-serve` `data/add` with an https URI | only when the caller supplies that URI |
| `setup --install-hopper` | only when you ask for Hopper |
| `npm ci`, `npm run compile` | only while you build this clone |

Verification performed on this machine: with `npm`, `bun`, `npx`, `curl` and
`git` replaced by logging stubs on `PATH`, `rea --version`, `rea --help`,
`rea update` and `rea doctor` invoked none of them.

## 2. Nothing is pushed upstream

- `origin` is the fork and the only push target (`remote.pushDefault=origin`).
- `upstream` exists for manual reads only; its push URL is the sentinel
  `DISABLED_no_push_to_upstream`, so a push cannot resolve.
- `.githooks/pre-push` (enabled via `core.hooksPath`) refuses any push whose
  remote URL is not `https://github.com/amitchhetri43/reverse-eng`.
- GitHub Actions is disabled on the fork, so no CI job can run upstream's
  publish, MCP-registry or remote-cache workflows from this repository.

Fetching new upstream commits is a manual act:

```sh
git fetch upstream
git log --oneline HEAD..upstream/main   # read before merging
```

## Updating the installed CLI

```sh
bash scripts/fork-reinstall.sh           # builds this clone, then replaces dist
```

The script compiles what is on disk and `rsync`s `dist/` over the installed
package. It never downloads a package.
