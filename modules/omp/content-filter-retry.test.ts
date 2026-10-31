import { describe, expect, test } from "bun:test";
import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";
import contentFilterRetry from "./extensions/content-filter-retry.ts";

type Message = {
  role?: string;
  content?: { type: string; text?: string }[];
  stopReason?: string;
  errorMessage?: string;
};

type StopResult = { continue: boolean; additionalContext: string } | undefined;
type StopHandler = (event: { last_assistant_message?: Message }, ctx: { agent: { kind: string } }) => StopResult;
type ContextHandler = (event: { messages: Message[] }) => { messages: Message[] } | undefined;

let onStop: StopHandler;
let onContext: ContextHandler;

contentFilterRetry({
  on(name: string, callback: StopHandler | ContextHandler) {
    if (name === "session_stop") onStop = callback as StopHandler;
    if (name === "context") onContext = callback as ContextHandler;
  },
} as unknown as ExtensionAPI);

const main = { agent: { kind: "main" } };
const termination = "Provider finish_reason: content_filter";

describe("session_stop retry", () => {
  test("retries a content-filter failure", () => {
    const result = onStop({ last_assistant_message: { role: "assistant", stopReason: "error", errorMessage: termination, content: [] } }, main);
    expect(result?.continue).toBe(true);
    expect((result?.additionalContext ?? "").length).toBeGreaterThan(0);
  });

  test("retries when partial text was streamed", () => {
    const result = onStop(
      {
        last_assistant_message: {
          role: "assistant",
          stopReason: "error",
          errorMessage: termination,
          content: [{ type: "text", text: "partial" }],
        },
      },
      main,
    );
    expect(result?.continue).toBe(true);
    expect((result?.additionalContext ?? "").length).toBeGreaterThan(0);
  });

  for (const type of ["toolCall", "image", "anthropicServerTool"]) {
    test(`does not retry a failure that carried a ${type} block`, () => {
      const result = onStop(
        {
          last_assistant_message: {
            role: "assistant",
            stopReason: "error",
            errorMessage: termination,
            content: [{ type }],
          },
        },
        main,
      );
      expect(result).toBeUndefined();
    });
  }

  test("does not retry inside a subagent", () => {
    const result = onStop(
      {
        last_assistant_message: {
          role: "assistant",
          stopReason: "error",
          errorMessage: termination,
          content: [{ type: "text", text: "partial" }],
        },
      },
      { agent: { kind: "sub" } },
    );
    expect(result).toBeUndefined();
  });

  test("ignores a successful turn", () => {
    const result = onStop({ last_assistant_message: { role: "assistant", stopReason: "stop", content: [] } }, main);
    expect(result).toBeUndefined();
  });

  test("ignores a retriable provider error", () => {
    const result = onStop(
      { last_assistant_message: { role: "assistant", stopReason: "error", errorMessage: "429 too many requests", content: [] } },
      main,
    );
    expect(result).toBeUndefined();
  });
});

describe("context replay guard", () => {
  test("drops the failed turn before the retry request", () => {
    const user: Message = { role: "user", content: [{ type: "text", text: "hi" }] };
    const failed: Message = { role: "assistant", stopReason: "error", errorMessage: termination, content: [] };
    const ok: Message = { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "done" }] };
    expect(onContext({ messages: [user, failed, ok] })).toEqual({ messages: [user, ok] });
  });

  for (const type of ["toolCall", "image", "anthropicServerTool"]) {
    test(`keeps a failed turn that carried a ${type} block`, () => {
      const failed: Message = {
        role: "assistant",
        stopReason: "error",
        errorMessage: termination,
        content: [{ type }],
      };
      expect(onContext({ messages: [{ role: "user", content: [] }, failed] })).toBeUndefined();
    });
  }

  test("leaves an unaffected history alone", () => {
    expect(
      onContext({
        messages: [
          { role: "user", content: [] },
          { role: "assistant", stopReason: "stop", content: [{ type: "text", text: "ok" }] },
        ],
      }),
    ).toBeUndefined();
  });
});
