require("byesu")
require("closerouter")
require("llm_labile")
require("commit_gate")
require("comment_gate")
require("git_upstream_gate")

maki.setup({
  always_yolo = true,
  always_thinking = "adaptive",
  ui = {
    thinking_lines = -1,
  },
  agent = {
    compaction_buffer = "40%",
  },
  provider = {
    low_speed_timeout_secs = 90,
    max_retries = 1000,
    max_timeout_retries = 1000,
  },
})
