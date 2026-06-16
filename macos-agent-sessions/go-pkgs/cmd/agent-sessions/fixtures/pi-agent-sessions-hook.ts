import { spawn } from "node:child_process"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"

export default function (pi: ExtensionAPI) {
  pi.on("agent_end", async (_event, ctx) => {
    const cwd = ctx.cwd
    const sessionId = ctx.sessionManager.getSessionId()
    const sessionName = ctx.sessionManager.getSessionName()

    const payload = JSON.stringify({
      event: "session.finished",
      dir: cwd,
      pi: {
        sessionId,
        sessionName: sessionName ?? null,
        nativeEvent: "agent_end",
      },
    })

    spawn("agent-sessions", [
      "notify", "--payload", payload,
    ], { detached: true, stdio: "ignore" }).unref()
  })
}
