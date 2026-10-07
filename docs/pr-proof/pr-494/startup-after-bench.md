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
          "fps": 1.44,
          "buildAvgMs": 13.33,
          "buildWorstMs": 29,
          "rasterAvgMs": 29.03,
          "rasterWorstMs": 485.4,
          "worstFrameMs": 546.1,
          "jankPercent": 96.3,
          "slowFramePercent": 11.11,
          "frames": 27,
          "devicePixelRatio": 2,
          "sampleSequence": 25,
          "sessionFrames": 27,
          "sessionWorstBuildMs": 29,
          "sessionWorstRasterMs": 485.4,
          "sessionWorstFrameMs": 546.1,
          "sessionOver200ms": 1,
          "sessionOverBudgetPercent": 96.3,
          "sessionSlowFramePercent": 11.11
        },
        "phase": "idle",
        "fps": 1.44,
        "rollingWorkJankPct": 96.3,
        "rollingSlowFramePct": 11.11,
        "sessionOver200ms": 1,
        "sessionOverBudgetPct": 96.3,
        "sessionSlowFramePct": 11.11,
        "avgBuildMs": 13.33,
        "avgRasterMs": 29.03,
        "worstBuildMs": 29,
        "worstRasterMs": 485.4,
        "worstFrameMs": 546.1,
        "sessionFrames": 27,
        "freshFrames": 10,
        "sampleSequence": 25
      },
      "scroll": {
        "snapshot": {
          "fps": 2.62,
          "buildAvgMs": 3.42,
          "buildWorstMs": 26.1,
          "rasterAvgMs": 5.53,
          "rasterWorstMs": 20.5,
          "worstFrameMs": 38.6,
          "jankPercent": 7.5,
          "slowFramePercent": 0.83,
          "frames": 240,
          "devicePixelRatio": 2,
          "sampleSequence": 47,
          "sessionFrames": 366,
          "sessionWorstBuildMs": 29,
          "sessionWorstRasterMs": 485.4,
          "sessionWorstFrameMs": 546.1,
          "sessionOver200ms": 1,
          "sessionOverBudgetPercent": 18.58,
          "sessionSlowFramePercent": 1.64
        },
        "phase": "scroll",
        "fps": 2.62,
        "rollingWorkJankPct": 7.5,
        "rollingSlowFramePct": 0.83,
        "sessionOver200ms": 1,
        "sessionOverBudgetPct": 18.58,
        "sessionSlowFramePct": 1.64,
        "avgBuildMs": 3.42,
        "avgRasterMs": 5.53,
        "worstBuildMs": 29,
        "worstRasterMs": 485.4,
        "worstFrameMs": 546.1,
        "sessionFrames": 366,
        "freshFrames": 339,
        "sampleSequence": 47
      },
      "movement": {
        "initial": 0,
        "maxOffset": 475,
        "final": 100
      },
      "renderer": "ANGLE (NVIDIA, NVIDIA GeForce RTX 4070 (0x00002786) Direct3D11 vs_5_0 ps_5_0, D3D11)",
      "longTasks": {
        "count": 9,
        "worstMs": 1514,
        "totalMs": 3345,
        "overBar": 4
      },
      "error": "full session exceeded the 200ms long-task budget"
    }
  ]
}
```
