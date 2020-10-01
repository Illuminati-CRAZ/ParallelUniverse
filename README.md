# ParallelUniverse
WIP, may/probably will have bugs

Each layer in the map is considered a "universe."
Default layer is universe 0, layer 1 is universe 1, layer 2 is universe 2, etc.
Notes in the last layer are ignored.

The visiblity of notes will depend on which universe they are in.
Universes are divided into one million ms (16.67 min) equivalent segments in position.

The "Hide Layer" button adds SVs so that notes in the selected layer are moved to the correct universe.
The "Unhide Layer" button removes the SVs.
The "Move to Layer" button moves selected notes to the selected layer. (This is already an editor feature, but it's easier to click this button.)

The teleport buttons add SVs to teleport between universes.

The "Increase SV by .5" button is just there.

The "Hide Layers" toggle changes the visibility of layers to reflect the gameplay, also prevents you from undoing actions lmao.
