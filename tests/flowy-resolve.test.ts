/**
 * Tests for hooks/flowy-resolve.sh — the shared FLOW.md resolver sourced by both
 * flowy-inject.sh and flowy-recompact.sh. The integration suites exercise it through
 * the hooks; this asserts the resolution CONTRACT directly so a future change to the
 * resolver is caught at the unit level, not only via the two consumers.
 */
import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import { existsSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const GIT_BASH = [
  "C:\\Program Files\\Git\\bin\\bash.exe",
  "C:\\Program Files (x86)\\Git\\bin\\bash.exe",
].find((p) => existsSync(p));
const HERE = fileURLToPath(new URL(".", import.meta.url));
const HELPER = join(HERE, "..", "hooks", "flowy-resolve.sh");

function toPosix(p: string): string {
  return p.replace(/^([A-Za-z]):/, (_m, d) => `/${d.toLowerCase()}`).replace(/\\/g, "/");
}

// flowy_resolve_flowmd NAME REF LOC PROJECT_FLOWS_DIR PLUGIN_ROOT -> resolved path (or "")
function resolve(name: string, ref: string, loc: string, pfd: string, pr: string): string {
  if (!GIT_BASH) return "";
  const r = spawnSync(
    GIT_BASH,
    ['-c', '. "$1"; flowy_resolve_flowmd "$2" "$3" "$4" "$5" "$6"', "_", toPosix(HELPER), name, ref, loc, pfd, pr],
    { encoding: "utf8" },
  );
  return (r.stdout ?? "").trim();
}

let root: string;
beforeAll(() => {
  root = mkdtempSync(join(tmpdir(), "flowy-resolve-"));
});
afterAll(() => {
  try {
    rmSync(root, { recursive: true, force: true });
  } catch {
    /* best-effort */
  }
});

describe("flowy_resolve_flowmd (shared resolver contract)", () => {
  test("plugin ref, auto-repair, project, traversal-dropped, bad-name, missing", () => {
    if (!GIT_BASH) return; // loud-skip without Git Bash
    const base = mkdtempSync(join(root, "case ")); // space exercises quoting
    const prWin = join(base, "plugin");
    const pfdWin = join(base, "proj", ".flowy", "flows");
    mkdirSync(join(prWin, "flows", "sp"), { recursive: true });
    writeFileSync(join(prWin, "flows", "sp", "FLOW.md"), "x");
    mkdirSync(join(pfdWin, "sp"), { recursive: true });
    writeFileSync(join(pfdWin, "sp", "FLOW.md"), "y");
    const PR = toPosix(prWin);
    const PFD = toPosix(pfdWin);

    // plugin resolution via the stored ref
    expect(resolve("sp", "flows/sp/FLOW.md", "plugin", PFD, PR)).toBe(`${PR}/flows/sp/FLOW.md`);
    // auto-repair: a stale ref falls back to flows/<name>/FLOW.md under the plugin root
    expect(resolve("sp", "flows/stale/FLOW.md", "plugin", PFD, PR)).toBe(`${PR}/flows/sp/FLOW.md`);
    // project resolution (no plugin fallback)
    expect(resolve("sp", "flows/sp/FLOW.md", "project", PFD, PR)).toBe(`${PFD}/sp/FLOW.md`);
    // traversal ref is dropped, then auto-repairs to the plugin canonical path
    expect(resolve("sp", "../../../etc/hosts", "plugin", PFD, PR)).toBe(`${PR}/flows/sp/FLOW.md`);
    // unsafe name + non-resolving ref -> empty. (A VALID ref wins first, so the bad name only
    // matters once we fall through to name-based auto-repair — give it a missing ref to get there.)
    expect(resolve("../evil", "flows/nope/FLOW.md", "plugin", PFD, PR)).toBe("");
    // missing flow -> empty
    expect(resolve("nope", "flows/nope/FLOW.md", "plugin", PFD, PR)).toBe("");
    // project with a missing file -> empty (NO plugin rescue, even though plugin sp exists)
    expect(resolve("sp", "flows/sp/FLOW.md", "project", toPosix(join(base, "empty")), PR)).toBe("");
  });
});
