-- Keep drag geometry exact and prevent a fading snapshot on desktop changes.
-- Scoped to the clock only; other Omarchy layers keep their own animations.
hl.layer_rule({
  match = { namespace = "^omarchy-desktop-clock(-input)?$" },
  no_anim = true,
  animation = "none",
})
