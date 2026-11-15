// Nothing under the settings screens while a world is visible: no tiled
// background, no veil. The title screen keeps the game's own look.
fn backdrop(batch: &mut crate::hud::HudBatch, atlas: &crate::hud::HudAtlas, in_world: bool) {
    if in_world {
        return;
    }
    let (w, h) = (batch.width, batch.height);
    crate::ui::menu_background(batch, atlas, 0.0, 0.0, w, h, in_world);
    crate::graphics_style::fill(batch, atlas, [0.0, 0.0, w, h], crate::graphics_style::VEIL);
}
