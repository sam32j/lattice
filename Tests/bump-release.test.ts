// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import { afterEach, expect, test } from "bun:test";
import { execFileSync } from "node:child_process";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";

const script = resolve("Tools/bump-release.ts");
const roots: string[] = [];
const git = (cwd: string, ...args: string[]) => execFileSync("git", [
  "-c", "user.name=Bump Test", "-c", "user.email=test@example.invalid",
  "-c", "commit.gpgsign=false", ...args,
], { cwd, encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] }).trim();

afterEach(() => { for (const root of roots.splice(0)) rmSync(root, { recursive: true, force: true }); });

function fixture() {
  const root = mkdtempSync(join(tmpdir(), "lattice-bump-test-"));
  roots.push(root);
  git(root, "init", "-b", "lattice/main");
  mkdirSync(join(root, "Downstream"));
  mkdirSync(join(root, "Tools"));
  writeFileSync(join(root, "Downstream/release.json"), JSON.stringify({
    upstreamTag: "v3.4.1",
    upstreamCommit: "aea106cb5d52045c99810cf672da891d2a20b67d",
    baseCommit: "794608a58d8a88608d3c3cb2e4f22373cf52bfdc",
    revision: 1,
    allowSnapshotRelease: true
  }, null, 2) + "\n");
  writeFileSync(join(root, "Downstream/CHANGELOG.md"), "# Lattice Changelog\n\nNotable additions.\n\n");
  git(root, "add", ".");
  git(root, "commit", "-m", "chore: initial downstream");
  git(root, "tag", "v3.4.1-d.1");

  const run = (args: string[] = []) => Bun.spawnSync(["bun", script, ...args], {
    cwd: root,
    stdout: "pipe",
    stderr: "pipe",
  });

  return { root, run };
}

test("bump-release parses conventional commits, bumps revision, and prepends to CHANGELOG.md", () => {
  const f = fixture();
  writeFileSync(join(f.root, "file1.txt"), "hello");
  git(f.root, "add", ".");
  git(f.root, "commit", "-m", "feat(recorder): add delayed start mode");

  writeFileSync(join(f.root, "file2.txt"), "world");
  git(f.root, "add", ".");
  git(f.root, "commit", "-m", "fix(editor): fix text undo crash");

  const result = f.run();
  expect(result.exitCode).toBe(0);

  const meta = JSON.parse(readFileSync(join(f.root, "Downstream/release.json"), "utf8"));
  expect(meta.revision).toBe(2);

  const changelog = readFileSync(join(f.root, "Downstream/CHANGELOG.md"), "utf8");
  expect(changelog).toContain("## [3.4.1-d.2]");
  expect(changelog).toContain("### Added");
  expect(changelog).toContain("- **Recorder**: Add delayed start mode");
  expect(changelog).toContain("### Fixed");
  expect(changelog).toContain("- **Editor**: Fix text undo crash");
});

test("bump-release respects --dry-run without modifying files", () => {
  const f = fixture();
  writeFileSync(join(f.root, "file1.txt"), "hello");
  git(f.root, "add", ".");
  git(f.root, "commit", "-m", "feat(quick-preview): add ocr shortcuts");

  const result = f.run(["--dry-run"]);
  expect(result.exitCode).toBe(0);
  expect(result.stdout.toString()).toContain("Dry run: no files modified.");

  const meta = JSON.parse(readFileSync(join(f.root, "Downstream/release.json"), "utf8"));
  expect(meta.revision).toBe(1);

  const changelog = readFileSync(join(f.root, "Downstream/CHANGELOG.md"), "utf8");
  expect(changelog).not.toContain("## [3.4.1-d.2]");
});

test("bump-release parses commit body bullet points as nested sub-bullets", () => {
  const f = fixture();
  writeFileSync(join(f.root, "file1.txt"), "hello");
  git(f.root, "add", ".");
  git(f.root, "commit", "-m", "feat(quick-preview): revamp preview layout\n\n- Dedicated action cards for save and shelf\n- Instant dual text and QR extraction\nCo-authored-by: Bob <bob@example.com>");

  const result = f.run();
  expect(result.exitCode).toBe(0);

  const changelog = readFileSync(join(f.root, "Downstream/CHANGELOG.md"), "utf8");
  expect(changelog).toContain("- **Quick Preview**: Revamp preview layout");
  expect(changelog).toContain("  - Dedicated action cards for save and shelf");
  expect(changelog).toContain("  - Instant dual text and QR extraction");
  expect(changelog).not.toContain("Co-authored-by");
});
