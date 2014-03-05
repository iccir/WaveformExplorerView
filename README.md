WaveformExplorerView
====================

Quick brain dump:

Cocoa view for displaying an audio waveform inside of a magnify-enabled NSScrollView

1. Uses GCD and Accelerate.framework to compute the waveform previews really fast
2. Displays waveform previews using tiled CALayers (but not CATiledLayer, as that's 2-d, and we want 1-d zooming)

Classes:

1. WaveSampleArray - tiny wrapper around a float array.  Uses GCD/Accelerate to make smaller versions of itself
2. WaveformExplorerView - main view class, sets up a scroll view and populates it with a WaveformChannelView
3. WaveformChannelView - represents one channel of audio.  In theory, WaveformExplorerView could handle multiple channels in the future
4. WaveformRepresentationView - represents the waveform at a specific detail level.  Responsible for tiling individual CALayers

