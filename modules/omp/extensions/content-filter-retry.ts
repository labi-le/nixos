import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

const CONTENT_FILTER = /content_filter/i;

const RETRY_NOTICE =
  "The previous response was rejected by the provider's content filter (finish_reason: content_filter). That failed turn has been removed from this context. Answer the user's last request again now; if the blocked output contained incidental content, rephrase it. Do not mention this notice.";

type Candidate = {
  role?: string;
  content?: unknown;
  stopReason?: string;
  errorMessage?: string;
};

function isContentFilterFailure(message: Candidate): boolean {
  return (
    message.role === "assistant" &&
    message.stopReason === "error" &&
    CONTENT_FILTER.test(message.errorMessage ?? "")
  );
}

function blocksReplay(message: Candidate): boolean {
  if (!Array.isArray(message.content)) return false;
  return message.content.some((block) => {
    const type = (block as { type?: unknown } | null | undefined)?.type;
    return type === "toolCall" || type === "image" || type === "anthropicServerTool";
  });
}

function retriable(message: unknown): message is Candidate {
  if (typeof message !== "object" || message === null) return false;
  const candidate = message as Candidate;
  return isContentFilterFailure(candidate) && !blocksReplay(candidate);
}

export default function (pi: ExtensionAPI) {
  pi.on("session_stop", (event, ctx) => {
    if (ctx.agent.kind !== "main") return;
    const message = event.last_assistant_message;
    if (!retriable(message)) return;
    return { continue: true, additionalContext: RETRY_NOTICE };
  });

  pi.on("context", (event) => {
    const messages = event.messages.filter((message) => !retriable(message));
    if (messages.length === event.messages.length) return;
    return { messages };
  });
}
