// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import { execFileSync } from "node:child_process";
import { writeFileSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
const repository = "sam32j/lattice";
const gh = (...args: string[]) => execFileSync("gh", args, { encoding: "utf8" }).trim();
try {
  const version = process.env.LATTICE_VERSION ?? "", commit = process.env.LATTICE_SOURCE_SHA ?? "";
  if (!/^\d+\.\d+\.\d+-d\.[1-9]\d*$/.test(version) || !/^[a-f0-9]{40}$/.test(commit)) throw new Error("Invalid release inputs");
  const live = JSON.parse(gh("api", `repos/${repository}/git/ref/heads/dev-build/main`));
  if (live.object.sha !== commit) throw new Error("Default branch moved after validation");
  const parts = (v: string) => v.replace(/^v/, "").split(/\.|-d\./).map(Number);
  const newer = (a: string, b: string) => {
    const right = parts(b);
    for (const [i, left] of parts(a).entries()) { if (left !== right[i]) return left > right[i]; }
    return false;
  };
  const releases = JSON.parse(gh("api", `repos/${repository}/releases?per_page=100`));
  for (const release of releases) {
    if (!release.draft && /^v\d+\.\d+\.\d+-d\.\d+$/.test(release.tag_name)
        && !newer(version, release.tag_name)) throw new Error("Release version must exceed every published Lattice version");
  }
  const tag = `v${version}`;
  const provenance = JSON.parse(readFileSync("Downstream/release.json", "utf8"));
  const notes = `Lattice ${version}\n\nUnofficial downstream build of Vorssaint. Source: ${commit}.\nUpstream: ${provenance.upstreamTag} (${provenance.upstreamCommit}); downstream revision ${provenance.revision}.\nProvenance is also included in LatticeProvenance.json inside the app.\nSigned with Samuel's configured Developer ID and notarized by Apple.\nRequires macOS 14 or later and Apple Silicon.\n`;
  writeFileSync("dist/release-notes.md", notes);
  gh("api", "--method", "POST", `repos/${repository}/git/refs`, "-f", `ref=refs/tags/${tag}`, "-f", `sha=${commit}`);
  gh("release", "create", tag, "--repo", repository, "--verify-tag", "--draft", "--title", `Lattice ${version}`,
    "--notes-file", "dist/release-notes.md", `dist/Lattice-${version}.dmg`, "dist/SHA256SUMS");
  const draft = JSON.parse(gh("release", "view", tag, "--repo", repository, "--json", "isDraft,tagName,targetCommitish,assets"));
  if (!draft.isDraft || draft.tagName !== tag || draft.assets.length !== 2) throw new Error("Draft release validation failed; draft retained for inspection");
  const remote = JSON.parse(gh("api", `repos/${repository}/releases/tags/${tag}`));
  for (const name of [`Lattice-${version}.dmg`, "SHA256SUMS"]) {
    const bytes = readFileSync(`dist/${name}`);
    const asset = remote.assets.find((a: { name: string }) => a.name === name);
    const digest = `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
    if (asset?.size !== bytes.length || asset?.digest !== digest)
      throw new Error(`Uploaded ${name} differs from validated local artifact; draft retained`);
  }
  const ref = JSON.parse(gh("api", `repos/${repository}/git/ref/tags/${tag}`));
  if (ref.object.sha !== commit) throw new Error("Release tag moved; draft retained");
  gh("release", "edit", tag, "--repo", repository, "--draft=false", "--latest");
} catch (error) {
  process.stderr.write(`Lattice publication stopped: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exitCode = 1;
}
