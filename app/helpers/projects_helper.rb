require "zlib"

module ProjectsHelper
  # A faint background tint per project, chosen from a fixed palette by
  # hashing the name (CRC32 -- a bucket hash, stable across restarts, unlike
  # String#hash). Deterministic, so no colour is stored and no picker is
  # needed. nil project -> nil (Inbox rows stay untinted).
  # Palette: a soft ~L92% shade of twelve well-spaced hues -- present, not loud.
  PROJECT_TINTS = %w[
    #fee2e2 #ffedd5 #fef3c7 #ecfccb #dcfce7 #ccfbf1
    #e0f2fe #dbeafe #e0e7ff #ede9fe #fae8ff #ffe4e6
  ].freeze

  def project_tint(project)
    return unless project

    PROJECT_TINTS[Zlib.crc32(project.name) % PROJECT_TINTS.size]
  end
end
