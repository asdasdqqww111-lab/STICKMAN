# Performance report

No frame-rate, memory, CPU, GPU, loading-time or Android measurements were taken. No 30/60 FPS claim is justified.

The current implementation limits visual prop cells to at most 9 (up to 36 instantiated assets), plus a fixed sphere, outpost, three waypoint markers, up to eight herbs and eight independently updated enemies. Map redraw cost grows with the number of discovered cells. This is a structural bound, not a benchmark. It has no terrain LOD, instancing, culling tuning, object pooling, background streaming, simulation LOD, texture compression policy or quality presets. Profile on representative Android devices after the gameplay and render paths are stable.
