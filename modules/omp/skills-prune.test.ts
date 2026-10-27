import { describe, expect, test } from "bun:test";
import { spawnSync } from "node:child_process";
import {
  existsSync,
  lstatSync,
  mkdirSync,
  mkdtempSync,
  readdirSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from "node:fs";
import { join } from "node:path";

const script = join(import.meta.dir, "skills-prune.sh");
const scratchRoot = "/tmp/nix";

function withFixture(body: (paths: { root: string; skills: string }) => void) {
  mkdirSync(scratchRoot, { recursive: true });
  const root = mkdtempSync(join(scratchRoot, "skills-prune-"));
  const skills = join(root, "skills");
  mkdirSync(skills);
  try {
    body({ root, skills });
  } finally {
    rmSync(root, { recursive: true, force: true });
  }
}

function run(skills: string, keep: string[]) {
  return spawnSync("bash", [script, skills, ...keep], { encoding: "utf8" });
}

function entries(dir: string) {
  return readdirSync(dir).sort();
}

describe("skills-prune", () => {
  test("removes a stale symlink without touching its target and keeps declared entries", () => {
    withFixture(({ root, skills }) => {
      const staleTarget = join(root, "stale-target");
      const declaredTarget = join(root, "declared-target");
      mkdirSync(staleTarget);
      mkdirSync(declaredTarget);
      writeFileSync(join(staleTarget, "SKILL.md"), "stale\n");
      writeFileSync(join(declaredTarget, "SKILL.md"), "declared\n");
      symlinkSync(staleTarget, join(skills, "stale"));
      symlinkSync(declaredTarget, join(skills, "declared"));

      const result = run(skills, ["declared"]);

      expect(result.status).toBe(0);
      expect(entries(skills)).toEqual(["declared"]);
      expect(existsSync(join(staleTarget, "SKILL.md"))).toBe(true);
      expect(existsSync(join(declaredTarget, "SKILL.md"))).toBe(true);
    });
  });

  test("removes stale directories and files and keeps declared ones", () => {
    withFixture(({ skills }) => {
      mkdirSync(join(skills, "stale-dir"));
      writeFileSync(join(skills, "stale-dir", "SKILL.md"), "stale\n");
      writeFileSync(join(skills, "stale.md"), "stale\n");
      mkdirSync(join(skills, "kept-dir"));
      writeFileSync(join(skills, "kept-dir", "SKILL.md"), "kept\n");
      writeFileSync(join(skills, "kept.md"), "kept\n");

      const result = run(skills, ["kept-dir", "kept.md"]);

      expect(result.status).toBe(0);
      expect(entries(skills)).toEqual(["kept-dir", "kept.md"]);
      expect(existsSync(join(skills, "kept-dir", "SKILL.md"))).toBe(true);
      expect(existsSync(join(skills, "kept.md"))).toBe(true);
    });
  });

  test("prunes a broken stale symlink and keeps a broken declared one", () => {
    withFixture(({ root, skills }) => {
      symlinkSync(join(root, "absent-stale"), join(skills, "stale"));
      symlinkSync(join(root, "absent-declared"), join(skills, "declared"));

      const result = run(skills, ["declared"]);

      expect(result.status).toBe(0);
      expect(entries(skills)).toEqual(["declared"]);
      expect(lstatSync(join(skills, "declared")).isSymbolicLink()).toBe(true);
    });
  });

  test("does nothing when the skills directory is missing", () => {
    withFixture(({ root }) => {
      const missing = join(root, "missing");

      const result = run(missing, ["kept"]);

      expect(result.status).toBe(0);
      expect(existsSync(missing)).toBe(false);
    });
  });

  test("refuses a symlinked root and leaves its target untouched", () => {
    withFixture(({ root }) => {
      const real = join(root, "real-skills");
      mkdirSync(join(real, "undeclared"), { recursive: true });
      writeFileSync(join(real, "undeclared", "SKILL.md"), "undeclared\n");
      const link = join(root, "linked-skills");
      symlinkSync(real, link);

      const result = run(link, ["kept"]);

      expect(result.status).not.toBe(0);
      expect(result.stderr).toContain("refusing");
      expect(lstatSync(link).isSymbolicLink()).toBe(true);
      expect(entries(real)).toEqual(["undeclared"]);
      expect(existsSync(join(real, "undeclared", "SKILL.md"))).toBe(true);
    });
  });
});
