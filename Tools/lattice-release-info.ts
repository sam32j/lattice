// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import { readFileSync, appendFileSync } from "node:fs";
import { execFileSync } from "node:child_process";

try {
  const identity = readFileSync("Sources/Lattice/Core/DownstreamIdentity.swift", "utf8");
  const team = identity.match(/static let signingTeamID = "([A-Za-z0-9]*)"/)?.[1] || "";
  const isAdhoc = team.toUpperCase() === "ADHOC" || process.env.LATTICE_ALLOW_ADHOC === "true";
  if (!isAdhoc && (!team || !/^[A-Z0-9]{10}$/.test(team) || team === "3D485NHW29"))
    throw new Error("Configure your own Developer ID signingTeamID before releasing Lattice");
  const meta = JSON.parse(readFileSync("Downstream/release.json", "utf8"));
  const allowSnapshot = Boolean(meta.allowSnapshotRelease);
  if (!/^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(meta.upstreamTag)
      || !/^[0-9a-f]{40}$/.test(meta.upstreamCommit) || !/^[0-9a-f]{40}$/.test(meta.baseCommit)
      || (!allowSnapshot && meta.baseCommit !== meta.upstreamCommit)
      || !Number.isSafeInteger(meta.revision) || meta.revision < 1)
    throw new Error("Release requires an exact published upstream stable base and a positive downstream revision");
  const git = (...args: string[]) => execFileSync("git", args, { encoding: "utf8" }).trim();
  const commit = git("rev-parse", "HEAD");
  if (process.env.LATTICE_SOURCE_SHA && process.env.LATTICE_SOURCE_SHA !== commit)
    throw new Error("Release source moved since sync");
  const live = git("ls-remote", "origin", "refs/heads/lattice/main").split(/\s/)[0];
  if (commit !== live) throw new Error("Only the current lattice/main commit may release");
  git("diff", "--exit-code", "HEAD");
  git("fetch", "--no-tags", "https://github.com/vorssaint/vorssaint-utils.git",
    `refs/tags/${meta.upstreamTag}:refs/tags/upstream/release`);
  if (git("rev-parse", "refs/tags/upstream/release^{commit}") !== meta.upstreamCommit)
    throw new Error("Upstream release tag moved");
  git("merge-base", "--is-ancestor", meta.upstreamCommit, meta.baseCommit);
  git("merge-base", "--is-ancestor", meta.baseCommit, commit);
  const version = `${meta.upstreamTag.slice(1)}-d.${meta.revision}`, tag = `v${version}`;
  if (git("ls-remote", "origin", `refs/tags/${tag}`)) throw new Error("Release tag already exists; do not replace published versions");
  const output = { team, version, tag, commit, upstream: meta.upstreamTag };
  process.stdout.write(JSON.stringify(output) + "\n");
  if (process.env.GITHUB_OUTPUT)
    appendFileSync(process.env.GITHUB_OUTPUT, Object.entries(output).map(([k, v]) => `${k}=${v}`).join("\n") + "\n");
} catch (error) {
  process.stderr.write(`Lattice release refused: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
