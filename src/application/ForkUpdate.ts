import { resolve } from "node:path";

import type { Result } from "../domain/result.js";

/**
 * Fork policy: this build is updated only from the owner's own fork, by hand.
 *
 * Two behaviours upstream ships are deliberately removed here:
 *
 * 1. the daily detached release check that queries the npm registry
 *    (`--incur-update-check`), disabled by `update: false` where the CLI is
 *    created; and
 * 2. the `rea update` installer, which shells out to `npm view` and
 *    `npm install -g`.
 *
 * Nothing in this module performs I/O. It reports the local procedure, so
 * `rea update` can never be the reason a request leaves the machine.
 */
export interface ForkUpdateReport {
  readonly status: "fork-managed";
  readonly installedVersion: string;
  readonly forkPath: string;
  readonly originRemote: string | null;
  readonly automaticChecks: "disabled";
  readonly networkPolicy: string;
  readonly manualSteps: readonly string[];
  readonly notes: readonly string[];
}

/** Directory of the fork clone, overridable with REA_FORK_PATH. */
export const forkPathFromEnvironment = (
  environment: Readonly<NodeJS.ProcessEnv>,
  homeDirectory: string,
): string => {
  const configured = environment.REA_FORK_PATH;
  return configured !== undefined && configured.length > 0
    ? resolve(configured)
    : resolve(homeDirectory, "reverse-eng");
};

/**
 * Describe how to apply new commits from the fork. Never contacts a registry,
 * a release feed, or the upstream repository.
 */
export const forkUpdateReport = (
  installedVersion: string,
  environment: Readonly<NodeJS.ProcessEnv>,
  homeDirectory: string,
): Result<ForkUpdateReport, string> => {
  const forkPath = forkPathFromEnvironment(environment, homeDirectory);
  const originRemote = environment.REA_FORK_REMOTE ?? null;
  return {
    ok: true,
    value: {
      status: "fork-managed",
      installedVersion,
      forkPath,
      originRemote,
      automaticChecks: "disabled",
      networkPolicy:
        "This build performs no release check and no package-manager lookup. Updates are fetched from the fork only, by hand.",
      manualSteps: [
        `git -C ${forkPath} fetch origin`,
        `git -C ${forkPath} merge --ff-only origin/main`,
        `bash ${forkPath}/scripts/fork-reinstall.sh`,
      ],
      notes: [
        "Upstream (morluto/rea) must stay unreachable for pushes; the fork's origin is the only push target.",
        "scripts/fork-reinstall.sh builds the local clone and replaces the installed dist, so no download is required.",
      ],
    },
  };
};
