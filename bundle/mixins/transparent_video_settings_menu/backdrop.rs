// Nothing under the settings screens while a world is visible: no tiled
// background and no veil, so a shader pack is judged on the world itself. The
// title screen keeps the game's own look, drawn by the original body.
//
// The body is not rewritten: the theme's colours move between Nightly builds
// (a `VEIL` const became `style::veil()`, for one), and this mod only needs to
// stop the drawing, not to draw it.
fn backdrop(
    batch: &mut crate::hud::HudBatch,
    atlas: &crate::hud::HudAtlas,
    in_world: bool,
) -> core::ops::ControlFlow<()> {
    let _ = (batch, atlas);
    if in_world {
        return core::ops::ControlFlow::Break(());
    }
    core::ops::ControlFlow::Continue(())
}
