#pragma once
#include "component.hpp"
#include "window.hpp"

#include <memory>
#include <vector>

namespace dusk::ui {

// Apply the Dusklight preset without showing the chooser and mark wasPresetChosen=true.
// Used on Switch where only this preset is offered (HayatoG/dusklight).
void apply_preset_dusk_silently();

class PresetWindow : public WindowSmall {
public:
    PresetWindow();

    bool focus() override;

protected:
    bool handle_nav_command(Rml::Event& event, NavCommand cmd) override;

private:
    std::vector<std::unique_ptr<Component>> mButtons;
};

}  // namespace dusk::ui
