// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Samuel Ji
import { appendFileSync } from "node:fs";
const tag = process.env.LATTICE_TAG ?? "";
if (!/^v\d+\.\d+\.\d+-d\.[1-9]\d*$/.test(tag)) throw new Error("Invalid Lattice tag");
const response = await fetch(`https://api.github.com/repos/sam32j/lattice/releases/tags/${tag}`, {
  headers: { Authorization: `Bearer ${process.env.GH_TOKEN}`, Accept: "application/vnd.github+json" },
});
if (response.status !== 200 && response.status !== 404) throw new Error(`Release lookup failed: HTTP ${response.status}`);
const pending = response.status === 404;
if (process.env.GITHUB_OUTPUT) appendFileSync(process.env.GITHUB_OUTPUT, `pending=${pending}\n`);
process.stdout.write(pending ? `New downstream release: ${tag}\n` : `${tag} already exists; no publication needed\n`);
