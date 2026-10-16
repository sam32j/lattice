// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
// Run with bun. All rebasing happens in a disposable clone, never the caller's checkout.
import { execFileSync } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync, appendFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const personal = "dev-build/main";
const root = mkdtempSync(join(tmpdir(), "lattice-sync-"));
const cwd = join(root, "checkout");
const env = { ...process.env, GIT_TERMINAL_PROMPT: "0", GIT_EDITOR: "true" };
function git(at: string, ...args: string[]) {
  return execFileSync("git", ["-c", "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false",
    "-c", "user.name=Lattice Sync", "-c", "user.email=78013800+sam32j@users.noreply.github.com",
    ...args], { cwd: at, env, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
}
function ancestor(base: string, head: string) {
  try { git(cwd, "merge-base", "--is-ancestor", base, head); return true; } catch { return false; }
}
function arg(name: string) {
  const index = process.argv.indexOf(name);
  const value = index >= 0 ? process.argv[index + 1] : undefined;
  if (!value || value.startsWith("-")) throw new Error(`Missing ${name}`);
  return value;
}
try {
  const fork = arg("--fork"), upstream = arg("--upstream"), tag = arg("--upstream-tag");
  if (!/^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/.test(tag)) throw new Error("Expected stable vX.Y.Z upstream tag");
  git(root, "clone", "--no-checkout", "--no-tags", "--", fork, cwd);
  const oldMain = git(cwd, "rev-parse", "refs/remotes/origin/main^{commit}");
  const oldPersonal = git(cwd, "rev-parse", `refs/remotes/origin/${personal}^{commit}`);
  git(cwd, "remote", "add", "upstream", upstream);
  git(cwd, "fetch", "--no-tags", "upstream", "refs/heads/main:refs/remotes/upstream/main",
    `refs/tags/${tag}:refs/tags/upstream/${tag}`);
  const nextMain = git(cwd, "rev-parse", "refs/remotes/upstream/main^{commit}");
  const release = git(cwd, "rev-parse", `refs/tags/upstream/${tag}^{commit}`);
  if (!ancestor(oldMain, nextMain)) throw new Error("Tracking main diverged; refusing to overwrite fork commits");
  if (!ancestor(release, nextMain)) throw new Error("Upstream stable tag is not on upstream main");
  const metadata = JSON.parse(git(cwd, "show", `${oldPersonal}:Downstream/release.json`));
  const sha = /^[0-9a-f]{40}$/;
  if (!sha.test(metadata.baseCommit) || !sha.test(metadata.upstreamCommit)
      || !/^v\d+\.\d+\.\d+$/.test(metadata.upstreamTag)
      || !Number.isSafeInteger(metadata.revision) || metadata.revision < 1) throw new Error("Invalid downstream provenance");
  if (!ancestor(metadata.baseCommit, oldPersonal)) throw new Error("Recorded upstream base is absent from personal history");
  git(cwd, "fetch", "--no-tags", "upstream", `refs/tags/${metadata.upstreamTag}:refs/tags/upstream/recorded`);
  if (git(cwd, "rev-parse", "refs/tags/upstream/recorded^{commit}") !== metadata.upstreamCommit)
    throw new Error("Recorded upstream tag was rewritten; manual review required");
  let ready = false, nextPersonal = oldPersonal;
  git(cwd, "checkout", "--detach", oldPersonal);
  if (release === metadata.baseCommit) {
    if (tag !== metadata.upstreamTag || release !== metadata.upstreamCommit)
      throw new Error("Stable release does not match recorded provenance");
    ready = true;
  } else if (ancestor(metadata.baseCommit, release)) {
    try {
      git(cwd, "rebase", "--rebase-merges", "--reapply-cherry-picks", "--empty=keep",
        "--onto", release, metadata.baseCommit);
    } catch {
      const conflicts = git(cwd, "diff", "--name-only", "--diff-filter=U");
      throw new Error(`Rebase stopped; remote branches untouched. Resolve conflicts manually:\n${conflicts}`);
    }
    metadata.baseCommit = release; metadata.upstreamCommit = release;
    metadata.upstreamTag = tag; metadata.revision = 1;
    writeFileSync(join(cwd, "Downstream/release.json"), JSON.stringify(metadata, null, 2) + "\n");
    git(cwd, "add", "Downstream/release.json");
    git(cwd, "commit", "-m", `chore(downstream): base Lattice on ${tag}`);
    nextPersonal = git(cwd, "rev-parse", "HEAD"); ready = true;
  } else if (!ancestor(release, metadata.baseCommit)) {
    throw new Error("Stable release and recorded upstream base diverged; manual review required");
  }
  const refs = [`${nextMain}:refs/heads/main`, `${nextPersonal}:refs/heads/${personal}`];
  const leases = [`--force-with-lease=refs/heads/main:${oldMain}`,
    `--force-with-lease=refs/heads/${personal}:${oldPersonal}`];
  if (nextPersonal !== oldPersonal) {
    const backup = `refs/heads/downstream-backups/${oldPersonal}`;
    refs.push(`${oldPersonal}:${backup}`); leases.push(`--force-with-lease=${backup}:`);
  }
  git(cwd, "push", "--atomic", ...leases, "origin", ...refs);
  const output = { commit: nextPersonal, ready, tag: `${tag}-d.${metadata.revision}`,
    changed: oldPersonal !== nextPersonal, held: ready ? "" : "Stable release predates preserved upstream snapshot" };
  process.stdout.write(JSON.stringify(output) + "\n");
  if (process.env.GITHUB_OUTPUT) {
    appendFileSync(process.env.GITHUB_OUTPUT, Object.entries(output).map(([k, v]) => `${k}=${v}`).join("\n") + "\n");
  }
} catch (error) {
  const detail = error instanceof Error ? error.message : String(error);
  process.stderr.write(`Lattice sync failed: ${detail}\n`); process.exitCode = 1;
} finally { rmSync(root, { recursive: true, force: true }); }
