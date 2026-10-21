export default {
  id: "tmux-activity",
  setup(context) {
    const pane = process.env.TMUX_PANE
    const dimAfterMs = 60 * 60 * 1_000
    const staleAfterMs = 2 * dimAfterMs
    if (!pane) return

    const setPaneOption = (name, value) => {
      Bun.spawn(["tmux", "set-option", "-p", "-t", pane, name, value], {
        stdout: "ignore",
        stderr: "ignore",
      })
    }
    const setActivity = (activity) => setPaneOption("@opencode_activity", activity)
    const setAttentionFlag = (activity, active) => {
      if (activity === "stage-attention") setPaneOption("@opencode_stage_waiting", active ? "1" : "0")
      else setPaneOption("@opencode_attention_waiting", active ? "1" : "0")
    }

    const setSummary = (title) => {
      const summary = String(title ?? "OpenCode")
        .replaceAll(/[\r\n#|]/g, " ")
        .trim()
        .split(/\s+/)
        .slice(0, 10)
        .join(" ")
      Bun.spawn(["tmux", "set-option", "-p", "-t", pane, "@opencode_summary", summary || "OpenCode"], {
        stdout: "ignore",
        stderr: "ignore",
      })
    }

    const setUpdatedAt = (updatedAt) => {
      Bun.spawn(
        ["tmux", "set-option", "-p", "-t", pane, "@opencode_updated_at", String(updatedAt ?? 0)],
        { stdout: "ignore", stderr: "ignore" },
      )
    }

    const setNextStep = (nextStep) => {
      const text = String(nextStep ?? "")
        .replaceAll(/[\r\n#|]/g, " ")
        .trim()
        .split(/\s+/)
        .slice(0, 10)
        .join(" ")
      const nextStepIsUsable = !text || !/\b(prompt|transient|internal|model|session|generation|instruction)\b/i.test(text)
      Bun.spawn(["tmux", "set-option", "-p", "-t", pane, "@opencode_next_step", nextStepIsUsable ? text : "No action needed"], {
        stdout: "ignore",
        stderr: "ignore",
      })
    }

    const currentSessionID = () => {
      const route = context.ui.router.current()
      if (route?.type === "session") return route.sessionID
      if (route?.name === "session") return route.params?.sessionID
      return undefined
    }

    let refreshing = false
    const nextStepForUpdate = new Map()
    const attentionForSession = new Map()

    const eventSessionID = (event) => event?.data?.sessionID ?? event?.properties?.sessionID
    const isStageQuestion = (request) =>
      request?.questions?.some(
        (question) =>
          question.header === "Staged changes" && question.question === "What should I do with the staged changes?",
      )
    const setAttention = (sessionID, activity) => {
      if (!sessionID) return
      if (activity === "stage-attention" || attentionForSession.get(sessionID) !== "stage-attention") {
        attentionForSession.set(sessionID, activity)
      }
    }
    const refresh = async () => {
      if (refreshing) return
      refreshing = true

      const sessionID = currentSessionID()
      if (!sessionID) {
        setActivity("idle")
        setSummary("OpenCode")
        setUpdatedAt(0)
        setNextStep("")
        refreshing = false
        return undefined
      }

      try {
        await context.data.session.sync(sessionID)
        if (sessionID !== currentSessionID()) return undefined

        const status = context.data.session.status(sessionID)
        const type = typeof status === "string" ? status : status?.type
        const session = context.data.session.get(sessionID)
        setSummary(session?.title)
        setUpdatedAt(session?.time?.updated)

        const pendingActivity = attentionForSession.get(sessionID)
        if (pendingActivity) {
          setAttention(sessionID, pendingActivity)
          setActivity(pendingActivity)
          return { session, type }
        }
        attentionForSession.delete(sessionID)

        if (["busy", "retry", "running", "working"].includes(type)) {
          setActivity("working")
          return { session, type }
        }

        const age = Date.now() - session?.time?.updated
        setActivity(age >= staleAfterMs ? "stale" : age >= dimAfterMs ? "aging" : "idle")
        return { session, type }
      } finally {
        refreshing = false
      }
    }

    const updateForCurrentSession = (event, activity) => {
      const sessionID = eventSessionID(event)
      if (sessionID && sessionID === currentSessionID()) setActivity(activity)
    }

    const generateNextStep = async (sessionID) => {
      const state = await refresh()
      const session = state?.session
      const type = state?.type
      const updatedAt = session?.time?.updated
      if (!session || ["busy", "retry", "running", "working"].includes(type)) return
      if (nextStepForUpdate.get(sessionID) === updatedAt) return

      nextStepForUpdate.set(sessionID, updatedAt)
      try {
        const result = await context.client.session.generate({
          sessionID,
          prompt:
            "You extract the user's next action from the completed work already in this session. " +
            "Return only one concrete imperative action for the user, in at most 10 words. " +
            "Never mention prompts, instructions, models, sessions, tools, or internal implementation. " +
            "Do not describe this request. If no user action remains, return exactly No action needed.",
        })
        const text = result?.data?.text ?? result?.text
        if (sessionID === currentSessionID() && text) setNextStep(text)
      } catch {
        nextStepForUpdate.delete(sessionID)
      }
    }

    const stopStarted = context.data.on("session.execution.started", (event) => {
      attentionForSession.delete(eventSessionID(event))
      updateForCurrentSession(event, "working")
    })
    const stopSucceeded = context.data.on("session.execution.succeeded", (event) => {
      const sessionID = eventSessionID(event)
      if (sessionID && sessionID === currentSessionID()) void generateNextStep(sessionID)
    })
    const stopFailed = context.data.on("session.execution.failed", refresh)
    const stopInterrupted = context.data.on("session.execution.interrupted", refresh)
    const stopQuestion = context.data.on("question.asked", (event) => {
      const request = event?.data ?? event?.properties
      const sessionID = eventSessionID(event)
      const activity = isStageQuestion(request) ? "stage-attention" : "attention"
      setAttention(sessionID, activity)
      if (sessionID && sessionID === currentSessionID()) {
        setActivity(activity)
        setAttentionFlag(activity, true)
        setNextStep(activity === "stage-attention" ? "Answer the /stage decision" : "Answer the pending question")
      }
    })
    const stopPermission = context.data.on("permission.asked", (event) => {
      const sessionID = eventSessionID(event)
      setAttention(sessionID, "attention")
      if (sessionID && sessionID === currentSessionID()) {
        setActivity(attentionForSession.get(sessionID))
        setAttentionFlag("attention", true)
        setNextStep("Respond to the permission request")
      }
    })
    const clearQuestionAttention = (event) => {
      const sessionID = eventSessionID(event)
      attentionForSession.delete(sessionID)
      if (sessionID && sessionID === currentSessionID()) {
        setAttentionFlag("stage-attention", false)
        setAttentionFlag("attention", false)
      }
      void refresh()
    }
    const stopQuestionReplied = context.data.on("question.replied", clearQuestionAttention)
    const stopQuestionRejected = context.data.on("question.rejected", clearQuestionAttention)
    const stopPermissionReplied = context.data.on("permission.replied", clearQuestionAttention)
    const interval = setInterval(() => void refresh(), 15_000)

    void refresh()
    return () => {
      clearInterval(interval)
      stopStarted()
      stopSucceeded()
      stopFailed()
      stopInterrupted()
      stopQuestion()
      stopPermission()
      stopQuestionReplied()
      stopQuestionRejected()
      stopPermissionReplied()
      setAttentionFlag("stage-attention", false)
      setAttentionFlag("attention", false)
      setActivity("idle")
    }
  },
}
