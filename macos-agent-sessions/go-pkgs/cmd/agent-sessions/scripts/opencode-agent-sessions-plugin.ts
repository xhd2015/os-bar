/**
 * os-bar agent-sessions opencode plugin.
 *
 * Listens for session.idle events (agent loop end) and notifies the
 * os-bar agent sessions macOS menu bar app.
 *
 * Install:
 *   agent-sessions install --opencode
 *   (global only: /config add plugin file://<path> if not auto-loaded)
 */

type PluginInput = {
  directory: string
  client?: {
    session: {
      get: (sessionID: string) => Promise<{ directory: string }>
    }
  }
}

type PluginEvent = {
  event: {
    id: string
    type: string
    properties: Record<string, unknown>
  }
}

type PluginHooks = {
  event?: (evt: PluginEvent) => void
  dispose?: () => void
}

export default {
  id: "os-bar-agent-sessions",

  server(input: PluginInput): PluginHooks {
    return {
      event({ event }) {
        // session.idle fires when the agent loop finishes (session runner goes idle).
        if (event.type !== "session.idle" && event.type !== "session.status") return

        const statusProps = event.properties as { status?: { type: string } } | undefined
        if (event.type === "session.status" && statusProps?.status?.type !== "idle") return

        const dir = input.directory
        if (!dir) return

        const sessionId = (event.properties as { sessionID?: string })?.sessionID ?? undefined

        const payload = JSON.stringify({
          source: "notify",
          event: "session.finished",
          dir,
          opencode: {
            sessionId: sessionId ?? null,
            nativeEvent: event.type,
          },
        })

        // Fire-and-forget notification
        const args = ["agent-sessions", "notify", "--payload", payload]
        if (typeof Bun !== "undefined") {
          Bun.spawn([args[0], ...args.slice(1)], {
            stdio: ["ignore", "ignore", "ignore"],
          })
        } else {
          import("node:child_process").then(({ spawn }) => {
            spawn(args[0], args.slice(1), {
              detached: true,
              stdio: "ignore",
            }).unref()
          }).catch(() => {})
        }
      },

      dispose() {},
    }
  },
}
