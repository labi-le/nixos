import { lookup } from "@oh-my-pi/pi-coding-agent/config/registry";
import { findScopedSettings } from "@oh-my-pi/pi-coding-agent/config/settings";
import { DelegationGate } from "./delegation-policy";

import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  const concurrency = lookup("task.maxConcurrency");
  const gate = new DelegationGate();

  pi.on("session_stop", (_event, ctx) => {
    if (ctx.agent.kind !== "main" || !concurrency) return;
    const settings = findScopedSettings();
    if (!settings) return;
    const max = concurrency.get(settings);
    if (typeof max !== "number") return;
    const jobs = ctx.getAsyncJobSnapshot();
    const active = jobs?.running.length ?? 0;
    const settled = jobs?.recent.filter(job => job.type === "task" || job.type === "eval").map(job => job.id) ?? [];
    if (!gate.shouldReconsider(ctx.sessionManager.getBranch(), max, active, settled)) return;

    return {
      decision: "block",
      reason: "Todo still has actionable work and subagent capacity is free. Reassess remaining tasks: delegate a concrete independent task only if that saves net effort. Do not create agents to fill slots. Handle short edits, integration, and verification directly; respect blocked tasks. Update todo as work progresses, and do not finish with actionable work outstanding.",
    };
  });
}
