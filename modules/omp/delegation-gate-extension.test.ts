import { expect, mock, test } from "bun:test";

let scopedSettings = { maxConcurrency: 1 };

mock.module("@oh-my-pi/pi-coding-agent/config/registry", () => ({
  lookup: () => ({ get: (settings: { maxConcurrency: number }) => settings.maxConcurrency }),
}));
mock.module("@oh-my-pi/pi-coding-agent/config/settings", () => ({
  findScopedSettings: () => scopedSettings,
}));

const { default: registerGate } = await import("./extensions/delegation-gate");

test("uses the active session's concurrency limit instead of global settings", () => {
  let onStop: ((event: unknown, context: unknown) => unknown) | undefined;
  registerGate({
    pi: { settings: { maxConcurrency: 2 } },
    on: (_event: string, callback: typeof onStop) => { onStop = callback; },
  } as never);

  const context = {
    agent: { kind: "main" },
    getAsyncJobSnapshot: () => ({ running: [{ id: "agent-1" }], recent: [] }),
    sessionManager: { getBranch: () => [{
      id: "todo-1",
      type: "message",
      message: { role: "toolResult", toolName: "todo", details: {
        op: "init", phases: [{ name: "Work", tasks: [{ content: "Implement component", status: "pending" }] }],
      } },
    }] },
  };
  expect(onStop?.({}, context)).toBeUndefined();

  scopedSettings = { maxConcurrency: 2 };
  expect(onStop?.({}, context)).toMatchObject({ decision: "block" });
});
