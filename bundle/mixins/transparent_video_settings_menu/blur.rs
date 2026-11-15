// A shader pack is judged on the world as it is drawn: the settings screen in
// a world asks for no menu blur, whatever `menuBackgroundBlurriness` says.
fn blur(game: &crate::game::Game<'_>) -> core::ops::ControlFlow<Option<f32>> {
    if game.title.is_none() && game.screen == Screen::Options {
        return core::ops::ControlFlow::Break(None);
    }
    core::ops::ControlFlow::Continue(())
}
