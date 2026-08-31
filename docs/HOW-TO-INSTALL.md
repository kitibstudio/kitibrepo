# Quick install — drop this scaffold into your MD project

cd /Users/macbookpro/Documents/Claude/Projects/MD

# 1. Extract the zip here (at the MD project root)
# 2. Run:
git add -A
git commit -m "Add Kitib process scaffolding — pre-audit baseline"

# 3. Verify Claude Code sees the agents:
#    Open Claude Code in this folder, then type:
#    /agents
#    You should see: reconciler, spec-tester, domain-checker, visual-critic, gate-reviewer

# 4. Add reference images (10 min — do this before running the visual critic):
#    test/reference/ia-writer.png      <- screenshot of iA Writer with a doc open
#    test/reference/issued-note.png    <- your firm's issued design note as PNG
#    test/reference/drawings/          <- a published consultancy SLD or riser

# 5. Run Session 0 — paste the prompt from docs/prompts.md into Claude Code

# 6. Read state/GAP.md yourself and resolve conflicts
# 7. Then: ./gauntlet.sh 1
