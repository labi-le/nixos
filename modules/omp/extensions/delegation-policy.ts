type Entry = {
  id: string;
  type: string;
  customType?: string;
  data?: { phases?: unknown };
  message?: {
    role?: string;
    toolName?: string;
    isError?: boolean;
    details?: { op?: string; phases?: unknown };
  };
};

function hasActionableWork(phases: unknown): boolean {
  return Array.isArray(phases) && phases.some(
    (phase) => typeof phase === "object" && phase !== null && Array.isArray(phase.tasks) &&
      phase.tasks.some((task: unknown) => typeof task === "object" && task !== null &&
        "status" in task && (task.status === "pending" || task.status === "in_progress")),
  );
}

export class DelegationGate {
  private lastPrompted: string | undefined;
  private seenCompletions = new Set<string>();

  shouldReconsider(entries: readonly Entry[], maxConcurrency: number, active: number, settledJobs: readonly string[] = []): boolean {
    if (maxConcurrency > 0 && active >= maxConcurrency) return false;
    const completions = new Set(settledJobs.map(id => `job:${id}`));

    for (let i = entries.length - 1; i >= 0; i--) {
      const entry = entries[i];
      if (!entry) continue;
      if (entry.type === "message" && entry.message?.role === "toolResult" &&
          entry.message.toolName === "task") {
        completions.add(`tool:${entry.id}`);
      }
      const phases = entry.type === "custom" && entry.customType === "user_todo_edit"
        ? entry.data?.phases
        : entry.type === "message" && entry.message?.role === "toolResult" &&
            entry.message.toolName === "todo" && !entry.message.isError && entry.message.details?.op !== "view"
          ? entry.message.details?.phases
          : undefined;
      if (!Array.isArray(phases)) continue;
      if (!hasActionableWork(phases)) return false;
      if (this.lastPrompted === entry.id) {
        let newCompletion = false;
        for (const id of completions) {
          if (!this.seenCompletions.has(id)) {
            newCompletion = true;
            break;
          }
        }
        if (!newCompletion) return false;
      }
      this.lastPrompted = entry.id;
      this.seenCompletions = completions;
      return true;
    }
    return false;
  }
}
