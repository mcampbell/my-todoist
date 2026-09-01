require "zlib"

module ProjectsHelper
  # A faint background tint per project, chosen from a fixed palette by
  # hashing the name (CRC32 -- a bucket hash, stable across restarts, unlike
  # String#hash). Deterministic, so no colour is stored and no picker is
  # needed. nil project -> nil (Inbox rows stay untinted).
  # Palette: the lightest shade of twelve well-spaced hues.
  PROJECT_TINTS = %w[
    #fef2f2 #fff7ed #fffbeb #f7fee7 #f0fdf4 #f0fdfa
    #f0f9ff #eff6ff #eef2ff #f5f3ff #fdf4ff #fff1f2
  ].freeze

  def project_tint(project)
    return unless project

    PROJECT_TINTS[Zlib.crc32(project.name) % PROJECT_TINTS.size]
  end
end
