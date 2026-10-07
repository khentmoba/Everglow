# Perf baseline

Verdict: **FAIL** · every requested run must complete; no long task >200ms.

Desktop/headless · 430x932 @ DPR 2 · CPU throttle 4x · 1 runs per scene.

Synthetic viewport/CPU settings are **not phone-calibrated**. This does not prove phone FPS,
presentation/dropped frames, interactivity, offline support, or feature-screen performance.
Rolling HUD FPS/work percentages are diagnostic only. Build/raster averages are final rolling
readings summarized by median; worst frame/build/raster values are cumulative session maxima
(including load/settle), maximized across ALL runs. No minimum/median of worsts is a guarantee.

| scene | phase | FPS median (diagnostic) | build avg median ms | raster avg median ms | session worst build ms | session worst raster ms | session worst frame ms | session worst long task ms |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| grid | incomplete/failed — no aggregate | | | | | | | |

## All raw runs

```json
{
  "grid": [
    {
      "scene": "grid",
      "run": 1,
      "build": "6.1.0+1-d0155111",
      "idle": {
        "snapshot": {
          "fps": 0.78,
          "buildAvgMs": 12.68,
          "buildWorstMs": 25.9,
          "rasterAvgMs": 29.1,
          "rasterWorstMs": 506.3,
          "worstFrameMs": 565.4,
          "jankPercent": 100,
          "slowFramePercent": 7.14,
          "frames": 28,
          "devicePixelRatio": 2,
          "sampleSequence": 26,
          "sessionFrames": 28,
          "sessionWorstBuildMs": 25.9,
          "sessionWorstRasterMs": 506.3,
          "sessionWorstFrameMs": 565.4,
          "sessionOver200ms": 1,
          "sessionOverBudgetPercent": 100,
          "sessionSlowFramePercent": 7.14
        },
        "phase": "idle",
        "fps": 0.78,
        "rollingWorkJankPct": 100,
        "rollingSlowFramePct": 7.14,
        "sessionOver200ms": 1,
        "sessionOverBudgetPct": 100,
        "sessionSlowFramePct": 7.14,
        "avgBuildMs": 12.68,
        "avgRasterMs": 29.1,
        "worstBuildMs": 25.9,
        "worstRasterMs": 506.3,
        "worstFrameMs": 565.4,
        "sessionFrames": 28,
        "freshFrames": 7,
        "sampleSequence": 26
      },
      "scroll": {
        "snapshot": {
          "fps": 9.91,
          "buildAvgMs": 2.87,
          "buildWorstMs": 16.2,
          "rasterAvgMs": 4.76,
          "rasterWorstMs": 9.1,
          "worstFrameMs": 23.7,
          "jankPercent": 3.75,
          "slowFramePercent": 0,
          "frames": 240,
          "devicePixelRatio": 2,
          "sampleSequence": 48,
          "sessionFrames": 408,
          "sessionWorstBuildMs": 32,
          "sessionWorstRasterMs": 506.3,
          "sessionWorstFrameMs": 565.4,
          "sessionOver200ms": 1,
          "sessionOverBudgetPercent": 13.73,
          "sessionSlowFramePercent": 0.98
        },
        "phase": "scroll",
        "fps": 9.91,
        "rollingWorkJankPct": 3.75,
        "rollingSlowFramePct": 0,
        "sessionOver200ms": 1,
        "sessionOverBudgetPct": 13.73,
        "sessionSlowFramePct": 0.98,
        "avgBuildMs": 2.87,
        "avgRasterMs": 4.76,
        "worstBuildMs": 32,
        "worstRasterMs": 506.3,
        "worstFrameMs": 565.4,
        "sessionFrames": 408,
        "freshFrames": 379,
        "sampleSequence": 48
      },
      "movement": {
        "initial": 0,
        "maxOffset": 475,
        "final": 100
      },
      "renderer": "ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 (0x00002786) Direct3D11 vs_5_0 ps_5_0, D3D11)",
      "longTasks": {
        "count": 10,
        "worstMs": 2067,
        "totalMs": 4061,
        "overBar": 5
      },
      "error": "full session exceeded the 200ms long-task budget"
    }
  ]
}
```
