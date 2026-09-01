require "zlib"

module ProjectsHelper
  # A faint background tint per project, chosen from a fixed palette by
  # hashing the name (CRC32 -- a bucket hash, stable across restarts, unlike
  # String#hash). Deterministic, so no colour is stored and no picker is
  # needed. nil project -> nil (Inbox rows stay untinted).
  # Palette: twelve hues spaced 30 deg apart at a fixed soft lightness, so any
  # two projects are a clear step apart in hue (no muddy near-matches) while
  # every colour stays a gentle pastel.
  PROJECT_TINTS = (0...12).map { |i| "hsl(#{i * 30}, 68%, 87%)" }.freeze

  def project_tint(project)
    return unless project

    PROJECT_TINTS[Zlib.crc32(project.name) % PROJECT_TINTS.size]
  end
end
