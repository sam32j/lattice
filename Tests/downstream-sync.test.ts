import { afterEach, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync, chmodSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";

const command = resolve("Tools/sync-downstream.ts");
const roots: string[] = [];
const git = (cwd: string, ...args: string[]) => execFileSync("git", [
  "-c", "user.name=Downstream Test", "-c", "user.email=test@example.invalid",
  "-c", "commit.gpgsign=false", ...args,
], { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();
afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "lattice-sync-test-")); roots.push(root);
  const upstream = join(root, "upstream"); mkdirSync(upstream);
  git(upstream, "init", "-b", "main");
  writeFileSync(join(upstream, "common"), "base\n"); git(upstream, "add", ".");
  git(upstream, "commit", "-m", "base"); git(upstream, "tag", "v1.0.0");
  const base = git(upstream, "rev-parse", "HEAD");
  const fork = join(root, "fork.git"); git(root, "clone", "--bare", upstream, fork);
  const personal = join(root, "personal"); git(root, "clone", fork, personal);
  git(personal, "checkout", "-b", "lattice/main");
  mkdirSync(join(personal, "Downstream"));
  writeFileSync(join(personal, "Downstream/release.json"), JSON.stringify({
    upstreamTag: "v1.0.0", upstreamCommit: base, baseCommit: base, revision: 1,
  }));
  writeFileSync(join(personal, "personal"), "keep my customizations\n");
  git(personal, "add", "."); git(personal, "commit", "-m", "personal patches");
  git(personal, "push", "origin", "HEAD");
  const before = git(personal, "rev-parse", "HEAD");
  const run = (tag = "v1.1.0", extraEnv = {}) => Bun.spawnSync([
    "bun", command, "--fork", fork, "--upstream", upstream, "--upstream-tag", tag,
  ], { cwd: root, env: { ...process.env, ...extraEnv }, stdout: "pipe", stderr: "pipe" });
  const advance = (conflict = false) => {
    writeFileSync(join(upstream, conflict ? "personal" : "upstream"), "upstream update\n");
    git(upstream, "add", "."); git(upstream, "commit", "-m", "upstream update");
    git(upstream, "tag", "v1.1.0");
  };
  return { root, upstream, fork, personal, before, base, run, advance };
}

test("sync preserves personal content, advances tracking main and records a stable upstream base", () => {
  const f = fixture(); f.advance(); const result = f.run();
  expect(result.stderr.toString()).toBe(""); expect(result.exitCode).toBe(0);
  expect(git(f.fork, "rev-parse", "main")).toBe(git(f.upstream, "rev-parse", "main"));
  expect(git(f.fork, "show", "lattice/main:personal")).toBe("keep my customizations");
  const metadata = JSON.parse(git(f.fork, "show", "lattice/main:Downstream/release.json"));
  expect(metadata.upstreamTag).toBe("v1.1.0"); expect(metadata.revision).toBe(1);
  expect(metadata.baseCommit).toBe(git(f.upstream, "rev-parse", "main"));
});

test("a rebase conflict changes neither remote branch", () => {
  const f = fixture(); f.advance(true); const result = f.run();
  expect(result.exitCode).toBe(1); expect(result.stderr.toString()).toContain("Rebase stopped");
  expect(git(f.fork, "rev-parse", "main")).toBe(f.base);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(f.before);
});

test("diverged tracking main is never overwritten", () => {
  const f = fixture(); f.advance();
  git(f.personal, "checkout", "main");
  writeFileSync(join(f.personal, "main-custom"), "keep this\n");
  git(f.personal, "add", "."); git(f.personal, "commit", "-m", "unexpected main customization");
  git(f.personal, "push", "origin", "main"); const main = git(f.personal, "rev-parse", "HEAD");
  expect(f.run().exitCode).toBe(1);
  expect(git(f.fork, "rev-parse", "main")).toBe(main);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(f.before);
});

test("an unchanged upstream release makes no personal commit", () => {
  const f = fixture(); const result = f.run("v1.0.0");
  expect(result.exitCode).toBe(0);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(f.before);
  expect(JSON.parse(result.stdout.toString()).changed).toBe(false);
});

test("a stable tag behind the preserved snapshot holds releases without dropping changes", () => {
  const f = fixture();
  writeFileSync(join(f.upstream, "snapshot"), "unreleased but already adopted\n");
  git(f.upstream, "add", "."); git(f.upstream, "commit", "-m", "unreleased snapshot");
  git(f.personal, "fetch", f.upstream, "main"); git(f.personal, "merge", "--no-edit", "FETCH_HEAD");
  const path = join(f.personal, "Downstream/release.json");
  const metadata = JSON.parse(readFileSync(path, "utf8")); metadata.baseCommit = git(f.upstream, "rev-parse", "HEAD");
  writeFileSync(path, JSON.stringify(metadata)); git(f.personal, "add", ".");
  git(f.personal, "commit", "-m", "record adopted snapshot"); git(f.personal, "push", "origin", "HEAD");
  const before = git(f.personal, "rev-parse", "HEAD"); const result = f.run("v1.0.0");
  expect(result.exitCode).toBe(0); expect(JSON.parse(result.stdout.toString()).ready).toBe(false);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(before);
  expect(git(f.fork, "show", "lattice/main:snapshot")).toBe("unreleased but already adopted");
});

test("allowSnapshotRelease permits release on unreleased snapshot and resets upon future upstream release", () => {
  const f = fixture();
  writeFileSync(join(f.upstream, "snapshot"), "unreleased but permitted\n");
  git(f.upstream, "add", "."); git(f.upstream, "commit", "-m", "unreleased snapshot");
  git(f.personal, "fetch", f.upstream, "main"); git(f.personal, "merge", "--no-edit", "FETCH_HEAD");
  const path = join(f.personal, "Downstream/release.json");
  const metadata = JSON.parse(readFileSync(path, "utf8"));
  metadata.baseCommit = git(f.upstream, "rev-parse", "HEAD");
  metadata.allowSnapshotRelease = true;
  writeFileSync(path, JSON.stringify(metadata)); git(f.personal, "add", ".");
  git(f.personal, "commit", "-m", "permit snapshot release"); git(f.personal, "push", "origin", "HEAD");
  const result = f.run("v1.0.0");
  expect(result.exitCode).toBe(0);
  expect(JSON.parse(result.stdout.toString()).ready).toBe(true);

  f.advance();
  const nextResult = f.run("v1.1.0");
  expect(nextResult.exitCode).toBe(0);
  expect(JSON.parse(nextResult.stdout.toString()).ready).toBe(true);
  const updatedMeta = JSON.parse(git(f.fork, "show", "lattice/main:Downstream/release.json"));
  expect(updatedMeta.upstreamTag).toBe("v1.1.0");
  expect(updatedMeta.allowSnapshotRelease).toBeUndefined();
});

test("rewriting a recorded upstream tag stops before either remote changes", () => {
  const f = fixture(); f.advance(); git(f.upstream, "tag", "-f", "v1.0.0");
  const result = f.run(); expect(result.exitCode).toBe(1);
  expect(result.stderr.toString()).toContain("rewritten");
  expect(git(f.fork, "rev-parse", "main")).toBe(f.base);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(f.before);
});

test("a missing personal branch is never silently recreated", () => {
  const f = fixture(); f.advance(); git(f.fork, "update-ref", "-d", "refs/heads/lattice/main");
  expect(f.run().exitCode).toBe(1); expect(git(f.fork, "rev-parse", "main")).toBe(f.base);
});

test("a concurrent personal push rejects the entire atomic ref update", () => {
  const f = fixture(); f.advance();
  writeFileSync(join(f.personal, "concurrent"), "new work during sync\n");
  git(f.personal, "add", "."); git(f.personal, "commit", "-m", "concurrent personal work");
  const concurrent = git(f.personal, "rev-parse", "HEAD");
  // Copy the commit object without moving a ref. A wrapper performs the actual
  // concurrent ref update immediately before the real Git push boundary.
  git(f.personal, "push", "origin", `${concurrent}:refs/heads/concurrent-object`);
  const realGit = execFileSync("which", ["git"], { encoding: "utf8" }).trim();
  const bin = join(f.root, "bin"); mkdirSync(bin);
  const wrapper = join(bin, "git");
  writeFileSync(wrapper, `#!/bin/sh\ncase " $* " in *" push --atomic "*)
"$REAL_GIT" --git-dir="$RACE_FORK" update-ref refs/heads/lattice/main "$RACE_SHA" "$RACE_OLD" || exit 88;; esac
exec "$REAL_GIT" "$@"\n`); chmodSync(wrapper, 0o755);
  const result = f.run("v1.1.0", { PATH: `${bin}:${process.env.PATH}`, REAL_GIT: realGit,
    RACE_FORK: f.fork, RACE_SHA: concurrent, RACE_OLD: f.before });
  expect(result.exitCode).toBe(1);
  expect(git(f.fork, "rev-parse", "main")).toBe(f.base);
  expect(git(f.fork, "rev-parse", "lattice/main")).toBe(concurrent);
});
