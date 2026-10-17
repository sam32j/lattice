// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { execFileSync } from "node:child_process";

const dryRun = process.argv.includes("--dry-run");
const force = process.argv.includes("--force");

function git(...args: string[]): string {
  return execFileSync("git", args, { encoding: "utf8" }).trim();
}

function formatScope(scope: string): string {
  return scope
    .split(/[-_]/)
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

try {
  const metaPath = "Downstream/release.json";
  if (!existsSync(metaPath)) throw new Error("Missing Downstream/release.json");
  const meta = JSON.parse(readFileSync(metaPath, "utf8"));

  // 1. Determine baseline tag or commit
  let baseRef = "";
  try {
    baseRef = git("describe", "--tags", "--match", "v*-d.*", "--abbrev=0");
  } catch {
    baseRef = meta.baseCommit;
  }
  if (!baseRef) throw new Error("Could not determine base reference for changelog");

  // 2. Fetch commits since baseline
  const rawLog = git("log", `${baseRef}..HEAD`, "--pretty=format:%H%x01%s%x01%b%x02");
  if (!rawLog) {
    console.log(`No new commits found since ${baseRef}`);
    process.exit(0);
  }

  const commitEntries = rawLog.split("\x02").map(e => e.trim()).filter(Boolean);

  const added: string[] = [];
  const fixed: string[] = [];
  const changed: string[] = [];

  const conventionalRegex = /^(feat|fix|perf|refactor|docs|style|test|ci|chore)(?:\(([^)]+)\))?: (.+)$/;

  for (const entry of commitEntries) {
    const [sha, subject, body] = entry.split("\x01");
    const match = subject.match(conventionalRegex);
    if (!match) continue;

    const [, type, scope, rawDesc] = match;
    const desc = rawDesc.charAt(0).toUpperCase() + rawDesc.slice(1);
    const scopePrefix = scope ? `**${formatScope(scope)}**: ` : "";
    const item = `- ${scopePrefix}${desc}`;

    switch (type) {
      case "feat":
        if (!added.includes(item)) added.push(item);
        break;
      case "fix":
        if (!fixed.includes(item)) fixed.push(item);
        break;
      case "perf":
      case "refactor":
        if (!changed.includes(item)) changed.push(item);
        break;
      default:
        break;
    }
  }

  if (added.length === 0 && fixed.length === 0 && changed.length === 0) {
    console.log(`No conventional feature or fix commits found since ${baseRef}`);
    process.exit(0);
  }

  // 3. Determine next revision
  let isCurrentRevisionPublished = false;
  const currentTag = `v${meta.upstreamTag.slice(1)}-d.${meta.revision}`;
  try {
    const existingTag = git("tag", "-l", currentTag);
    if (existingTag === currentTag) isCurrentRevisionPublished = true;
  } catch {}

  const nextRevision = isCurrentRevisionPublished ? meta.revision + 1 : meta.revision;
  const nextVersion = `${meta.upstreamTag.slice(1)}-d.${nextRevision}`;
  const today = new Date().toISOString().slice(0, 10);

  // 4. Build changelog section
  const lines: string[] = [];
  lines.push(`## [${nextVersion}] - ${today}`);
  lines.push("");

  if (added.length > 0) {
    lines.push("### Added");
    lines.push(...added);
    lines.push("");
  }
  if (changed.length > 0) {
    lines.push("### Changed");
    lines.push(...changed);
    lines.push("");
  }
  if (fixed.length > 0) {
    lines.push("### Fixed");
    lines.push(...fixed);
    lines.push("");
  }

  const newSection = lines.join("\n").trim() + "\n\n";

  console.log(`Generated release notes for Lattice ${nextVersion}:`);
  console.log("--------------------------------------------------");
  console.log(newSection);

  if (dryRun) {
    console.log("Dry run: no files modified.");
    process.exit(0);
  }

  // 5. Update Downstream/CHANGELOG.md
  const changelogPath = "Downstream/CHANGELOG.md";
  let changelogContent = existsSync(changelogPath)
    ? readFileSync(changelogPath, "utf8")
    : "# Lattice Changelog\n\nNotable additions and improvements specific to the Lattice downstream distribution.\n\n";

  if (changelogContent.includes(`## [${nextVersion}]`)) {
    if (!force) {
      console.log(`Note: Section for [${nextVersion}] already exists in ${changelogPath}. Skipping changelog insert (use --force to overwrite).`);
    } else {
      const escapedVersion = nextVersion.replace(/\./g, "\\.");
      const regex = new RegExp(`## \\[${escapedVersion}\\][\\s\\S]*?(?=\\n## \\[|$)`);
      changelogContent = changelogContent.replace(regex, newSection.trim());
      writeFileSync(changelogPath, changelogContent);
      console.log(`Updated existing [${nextVersion}] section in ${changelogPath}`);
    }
  } else {
    const headerMatch = changelogContent.match(/^# Lattice Changelog\n\n(?:[^\n]+\n\n)?/);
    if (headerMatch) {
      const header = headerMatch[0];
      const rest = changelogContent.slice(header.length);
      changelogContent = header + newSection + rest;
    } else {
      changelogContent = "# Lattice Changelog\n\n" + newSection + changelogContent;
    }
    writeFileSync(changelogPath, changelogContent);
    console.log(`Prepended [${nextVersion}] section to ${changelogPath}`);
  }

  // 6. Update Downstream/release.json
  if (nextRevision !== meta.revision) {
    meta.revision = nextRevision;
    writeFileSync(metaPath, JSON.stringify(meta, null, 2) + "\n");
    console.log(`Updated ${metaPath} to revision ${nextRevision}`);
  }

  console.log(`Release preparation complete: version ${nextVersion}`);
} catch (error) {
  console.error("Bump failed:", error instanceof Error ? error.message : String(error));
  process.exit(1);
}
