import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import commitGate from "./extensions/commit-gate.ts";

type Handler = (event: { toolName: string; input: Record<string, unknown> }, ctx: { cwd: string }) => Promise<{ block: boolean; reason: string } | undefined>;
let handler: Handler;
commitGate({
  on(name: string, callback: Handler) {
    if (name === "tool_call") handler = callback;
  },
  exec() {
    throw new Error("MR text checks must not execute commands");
  },
} as unknown as ExtensionAPI);

const push = "git push -u origin KID-4637 -o merge_request.create";
const cases: [string, string, boolean][] = [
  ["reported nonempty push description", `${push} -o merge_request.title=KID-4637 -o 'merge_request.description=Long prose about the implementation'`, true],
  ["explicit empty push description", `${push} -o merge_request.title=KID-4637 -o merge_request.description=`, false],
  ["create cannot inherit commit description", `${push} -o merge_request.title=Short`, true],
  ["create cannot inherit commit title", `${push} -o merge_request.description=`, true],
  ["ordinary push", "git push -u origin feature/topic", false],
  ["ordinary dynamic branch", 'git push origin "$BRANCH"', false],
  ["push title only update", "git push -o merge_request.title=Short", false],
  ["push description only update", "git push -o merge_request.description=prose", true],
  ["long push option", "git push --push-option merge_request.title=Short --push-option merge_request.description=", false],
  ["equals push option", "git push --push-option=merge_request.description=prose", true],
  ["attached push option", "git push -omerge_request.description=prose", true],
  ["inline config push option", "git -c push.pushOption=merge_request.description=prose push", true],
  ["attached inline config push option", "git -cpush.pushOption=merge_request.description=prose push", true],
  ["inline config valid MR", "git -c push.pushOption=merge_request.create -c push.pushOption=merge_request.title=Short -c push.pushOption=merge_request.description= push", false],
  ["unsafe configured push option", "git config --add push.pushOption merge_request.description=prose", true],
  ["safe configured push option", "git config --add push.pushOption merge_request.description=", false],
  ["short equals push option", "git push -o=merge_request.description=prose", true],
  ["repeated description cannot hide prose", "git push -o merge_request.description=prose -o merge_request.description=", true],
  ["repeated title cannot hide long title", `git push -o merge_request.title=${"x".repeat(71)} -o merge_request.title=Short`, true],
  ["whitespace description is not empty", "git push -o 'merge_request.description= '", true],
  ["dynamic push title", 'git push -o "merge_request.title=$TITLE"', true],
  ["dynamic push option", 'git push -o "$MR_OPTION"', true],
  ["valid gh create", "gh pr create --title 'Fix this.' --body ''", false],
  ["gh new alias", "gh pr new -t Short -b ''", false],
  ["valid glab create", "glab mr create --title Short --description ''", false],
  ["glab new alias", "glab mr new -t Short -d ''", false],
  ["gh missing title", "gh pr create --body ''", true],
  ["gh missing body", "gh pr create --title Short", true],
  ["glab missing title", "glab mr create --description ''", true],
  ["glab missing description", "glab mr create --title Short", true],
  ["gh nonempty body", "gh pr create -t Short -b prose", true],
  ["glab nonempty description", "glab mr create -t Short -d prose", true],
  ["unicode title at boundary", `gh pr create -t '${"😀".repeat(70)}' -b ''`, false],
  ["unicode title above boundary", `gh pr create -t '${"😀".repeat(71)}' -b ''`, true],
  ["newline title", "gh pr create -t 'First\nSecond' -b ''", true],
  ["carriage return title", "gh pr create -t 'First\rSecond' -b ''", true],
  ["gh global repo selector", "gh -R team/project pr create -t Short -b prose", true],
  ["gh draft metadata", "gh pr create -d -t Short -b ''", false],
  ["glab global repo selector", "glab --repo team/project mr update 1 -d prose", true],
  ["CLI Unicode line separator", "gh pr create -t 'First\u2028Second' -b ''", true],
  ["empty title", "gh pr create -t '' -b ''", true],
  ["blank title", "gh pr create -t ' ' -b ''", true],
  ["literal dollar title", "gh pr create -t '$TITLE costs $5' -b ''", false],
  ["expanded title", 'gh pr create -t "$TITLE" -b ""', true],
  ["positional expansion title", 'gh pr create -t "$1" -b ""', true],
  ["generated title", 'gh pr create -t "$(cat title.txt)" -b ""', true],
  ["backtick title", 'gh pr create -t "`cat title.txt`" -b ""', true],
  ["ANSI quoted title", "gh pr create -t $'First\\nSecond' -b ''", true],
  ["body from file", "gh pr create -t Short --body-file body.txt", true],
  ["body from stdin", "gh pr edit 1 --body-file -", true],
  ["glab description from file", "glab mr create -t Short --description @body.txt", true],
  ["gh short fill with explicit text", "gh pr create -f -t Short -b ''", true],
  ["glab short fill with explicit text", "glab mr create -f -t Short -d ''", true],
  ["gh short editor", "gh pr create -e -t Short -b ''", true],
  ["glab short editor", "glab mr create -e -t Short -d ''", true],
  ["glab fill commit body", "glab mr create --fill-commit-body -t Short -d ''", true],
  ["gh auto fill", "gh pr create --fill -t Short -b ''", true],
  ["gh fill body", "gh pr create --fill-verbose -t Short -b ''", true],
  ["gh template", "gh pr create -T template.md -t Short -b ''", true],
  ["gh editor", "gh pr create --editor -t Short -b ''", true],
  ["gh recovery", "gh pr create --recover state -t Short -b ''", true],
  ["glab fill", "glab mr create --fill -t Short -d ''", true],
  ["glab attachment", "glab mr create --attach file -t Short -d ''", true],
  ["glab signoff", "glab mr create --signoff -t Short -d ''", true],
  ["gh metadata edit", "gh pr edit 1 --add-label reviewed", false],
  ["glab metadata update", "glab mr update 1 --label reviewed", false],
  ["gh title edit", "gh pr edit 1 --title Short", false],
  ["gh body clear", "gh pr edit 1 --body=", false],
  ["gh body edit", "gh pr edit 1 --body=prose", true],
  ["glab description edit", "glab mr update 1 --description=prose", true],
  ["attached title and empty body", "gh pr create -tShort -b=", false],
  ["repeated CLI body", "gh pr edit 1 -b prose -b ''", true],
  ["dynamic metadata remains allowed", 'gh pr create -t Short -b "" --head "$BRANCH"', false],
  ["env wrapper", "env GH_HOST=github.com gh pr create -t Short -b prose", true],
  ["shell wrapper", `bash -lc "gh pr create -t Short -b prose"`, true],
  ["nested command wrapper", `command env bash -lc "glab mr create -t Short -d prose"`, true],
  ["ssh wrapper", `ssh host "git push -o merge_request.description=prose"`, true],
  ["multiple commands", "gh pr edit 1 --add-label reviewed; gh pr edit 1 -b prose", true],
  ["valid commit preserved", "git commit -m 'omp: fix gate'", false],
  ["invalid commit preserved", "git commit -m wip", true],
];

describe("MR text gate", () => {
  for (const [name, command, blocked] of cases) {
    test(name, async () => {
      const result = await handler({ toolName: "bash", input: { command } }, { cwd: process.cwd() });
      expect(result?.block ?? false).toBe(blocked);
    });
  }
  for (const code of [
    'subprocess.run(["gh", "pr", "create", "--title", title, "--body", body])',
    'subprocess.run(["glab", "mr", "update", "1", "--description", body])',
    'subprocess.run(["git", "push", "-o", "merge_request.create", "-o", option])',
    'command = "gh pr create " + options; subprocess.run(command, shell=True)',
  ]) {
    test(`opaque eval blocks: ${code}`, async () => {
      const result = await handler({ toolName: "eval", input: { code } }, { cwd: process.cwd() });
      expect(result?.block).toBe(true);
    });
  }
});
