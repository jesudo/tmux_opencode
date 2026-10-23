---
description: Learn from an agent misunderstanding and suggest a concise AGENTS.md improvement.
agent: plan
---

Help turn the agent misunderstanding described below into a small, durable improvement to the repository instructions. Incident context: $ARGUMENTS

This is a diagnostic and recommendation workflow. Do not modify any repository files, create a plan file, or use tools that make changes.

1. Locate and read the `AGENTS.md` files applicable to the current working directory. Read any instruction documents they route to that are relevant to the incident. Identify the `AGENTS.md` philosophy or equivalent stated design criteria before proposing a change.
2. Start a focused diagnostic interview with the question tool. Ask about the misunderstanding, the desired behavior, the task context, and any evidence of what instruction was missed or misread. Use the incident context above when it answers a question already. Ask only follow-up questions needed to distinguish a missing instruction, ambiguous wording, an incorrect route to detailed guidance, or an execution/model limitation.
3. Decide whether the lesson belongs in the applicable `AGENTS.md`, an existing linked instruction document, or a new task-specific document. Respect the repository's instruction philosophy: when `AGENTS.md` is a concise routing guide, keep it concise and route detailed procedures to task-specific documents instead of duplicating them.
4. Respond with:
   - **What went wrong:** a short, evidence-based explanation.
   - **Recommended instruction location:** the exact file and why it is the right scope.
   - **Suggested `AGENTS.md` improvement:** an exact minimal diff or replacement block. If detailed guidance is necessary, propose a concise route in `AGENTS.md` plus the needed companion-document change separately.
   - **Why this fits the instruction philosophy:** one or two sentences.
   - **Next step:** tell the user to review the suggestion, then switch to Build mode and ask to apply it if they approve.
5. Do not claim the recommendation was applied. If the existing instructions already adequately cover the issue, explain that clearly and suggest a non-instruction remedy instead.
