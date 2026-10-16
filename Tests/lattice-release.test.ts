import { expect, test } from "bun:test";
import { mkdtempSync, mkdirSync, writeFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { resolve, join } from "node:path";

const preflight = resolve("Tools/lattice-release-info.ts");
function refused(team: string, metadata: unknown) {
  const root = mkdtempSync(join(tmpdir(), "lattice-release-test-"));
  try {
    mkdirSync(join(root, "Sources/Vorssaint/Core"), { recursive: true });
    mkdirSync(join(root, "Downstream"));
    writeFileSync(join(root, "Sources/Vorssaint/Core/DownstreamIdentity.swift"),
      `static let signingTeamID = "${team}"\n`);
    writeFileSync(join(root, "Downstream/release.json"), JSON.stringify(metadata));
    return Bun.spawnSync(["bun", preflight], { cwd: root, stdout: "pipe", stderr: "pipe" });
  } finally { rmSync(root, { recursive: true, force: true }); }
}
test("missing and upstream signing pins cannot reach a release", () => {
  for (const team of ["", "3D485NHW29", "malformed"]) {
    const result = refused(team, {});
    expect(result.exitCode).toBe(1); expect(result.stderr.toString()).toContain("own Developer ID");
  }
});
test("an unreleased upstream snapshot cannot masquerade as a stable release", () => {
  const result = refused("ABC123DE45", { upstreamTag: "v3.4.1",
    upstreamCommit: "a".repeat(40), baseCommit: "b".repeat(40), revision: 1 });
  expect(result.exitCode).toBe(1); expect(result.stderr.toString()).toContain("exact published upstream stable base");
});
test("packaging without configured signing inputs fails before creating artifacts", () => {
  const result = Bun.spawnSync(["/bin/zsh", resolve("Tools/package-lattice.sh")], {
    env: { ...process.env, LATTICE_TEAM_ID: "", LATTICE_VERSION: "" }, stdout: "pipe", stderr: "pipe",
  });
  expect(result.exitCode).not.toBe(0); expect(result.stderr.toString()).toContain("validated fork team");
});
