import { describe, expect, test } from "bun:test";
import { DelegationGate } from "./extensions/delegation-policy";

function branch(status: string, id = "todo-1") {
  return [{
    id,
    type: "message",
    message: {
      role: "toolResult",
      toolName: "todo",
      details: { op: "init", phases: [{ name: "Work", tasks: [{ content: "Implement independent component", status }] }] },
    },
  }];
}

describe("delegation stop gate", () => {
  test("requires reconsidering delegation when work remains and a slot is free", () => {
    const gate = new DelegationGate();
    expect(gate.shouldReconsider(branch("pending"), 4, 0)).toBe(true);
  });

  test("does not nag indefinitely for unchanged work", () => {
    const gate = new DelegationGate();
    expect(gate.shouldReconsider(branch("pending"), 4, 0)).toBe(true);
    expect(gate.shouldReconsider(branch("pending"), 4, 0)).toBe(false);
    expect(gate.shouldReconsider(branch("pending", "todo-2"), 4, 0)).toBe(true);
  });

  test("rechecks the same todo after a synchronous subagent finishes", () => {
    const gate = new DelegationGate();
    const entries = branch("pending");
    expect(gate.shouldReconsider(entries, 4, 0)).toBe(true);
    expect(gate.shouldReconsider(entries, 4, 0)).toBe(false);
    expect(gate.shouldReconsider([...entries, {
      id: "task-result-1",
      type: "message",
      message: { role: "toolResult", toolName: "task", isError: false },
    }], 4, 0)).toBe(true);
  });

  test("rechecks after an async subagent settles without changing todo", () => {
    const gate = new DelegationGate();
    const entries = branch("pending");
    expect(gate.shouldReconsider(entries, 4, 0, ["job-1"])).toBe(true);
    expect(gate.shouldReconsider(entries, 4, 0, ["job-1"])).toBe(false);
    expect(gate.shouldReconsider(entries, 4, 0, ["job-1", "job-2"])).toBe(true);
    expect(gate.shouldReconsider(entries, 4, 0, ["job-2"])).toBe(false);
  });

  test("does not gate completed or blocked work", () => {
    const gate = new DelegationGate();
    expect(gate.shouldReconsider(branch("completed"), 4, 0)).toBe(false);
    expect(gate.shouldReconsider(branch("blocked"), 4, 0)).toBe(false);
  });

  test("does not gate while the capacity is exhausted", () => {
    const gate = new DelegationGate();
    expect(gate.shouldReconsider(branch("pending"), 2, 2)).toBe(false);
    expect(gate.shouldReconsider(branch("pending"), 2, 1)).toBe(true);
  });

  test("an unlimited cap still allows dispatch", () => {
    const gate = new DelegationGate();
    expect(gate.shouldReconsider(branch("in_progress"), 0, 1)).toBe(true);
  });

  test("ignores read-only todo views and failed updates", () => {
    const entries = [
      ...branch("pending"),
      { ...branch("completed", "todo-2")[0], message: { ...branch("completed", "todo-2")[0].message, details: { op: "view", phases: [{ name: "Work", tasks: [{ content: "Implement independent component", status: "completed" }] }] } } },
      { ...branch("completed", "todo-3")[0], message: { ...branch("completed", "todo-3")[0].message, isError: true } },
    ];
    expect(new DelegationGate().shouldReconsider(entries, 4, 0)).toBe(true);
  });

  test("no todo means no delegation demand", () => {
    expect(new DelegationGate().shouldReconsider([], 4, 0)).toBe(false);
  });
});
