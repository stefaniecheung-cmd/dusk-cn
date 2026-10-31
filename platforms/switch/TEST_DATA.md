# Switch 实机测试数据包（参考 HayatoG 编译版）

来源：HayatoG 编译完成的运行包（2026-06/07 构建），用于 `cn-switch` 分支的实机
测试基线。仓库只记录布局与用法，大二进制不入库。

## 包内容与用途

| 文件 | 大小 | 用途 |
|---|---|---|
| `dusklight.nro` | 52 MB | **基线 NRO**：HayatoG 已验证的成品。刷入 Switch 先跑通基线，再与我们构建的 NRO 对比（UI 中文、设置项、性能） |
| `The Legend of Zelda Twilight Princess.iso` | 991 MB | **游戏 dump**（GameCube 欧版 `GZ2P01`，精简版）。⚠️ 非 hash 完整镜像 → 需保持 `backend.isoVerification: 0`（参考包 config 即如此） |
| `pipeline_cache.db` + `dawn_cache.db` | 5 MB + 19 MB | **预热着色器缓存**。正是 cmake/switch/AuroraOptions.cmake 里 WS1（AURORA_ENABLE_GPU_CACHE）要消费的文件，装 SD 卡时一并放入数据目录可消除首次进游戏的着色器编译卡顿 |
| `texture_replacements/` | 2.4 GB | **HD 材质包**（`game.enableTextureReplacements: true` 启用）。Switch 与 Windows 构建通用 |
| `USA/Card A/--gczelda2.gci` | 36 KB | GC 存档（记忆卡 A），可用于验证存档导入/替换流程 |
| `config.json` | — | **实测可用的默认配置模板**：Boost+ 超频档（需 sys-clk-OC）、内部分辨率 ×4、关闭阴影、体感开启等 |
| `dusklight.log` | — | 性能参考：菜单 ~60fps，实机游玩 32–40fps（Boost+ 开启、内部分辨率 ×4 下） |

## SD 卡布局（与 romfs 自供给兼容）

```
sdmc:/TwilitRealm/Dusklight/
├── The Legend of Zelda Twilight Princess.iso
├── config.json
├── pipeline_cache.db
├── dawn_cache.db
├── texture_replacements/
└── USA/Card A/--gczelda2.gci
```

与 `src/dusk/data.cpp` 的 Switch 数据目录（`sdmc:/TwilitRealm/Dusklight`）及
romfs:/seed 首次启动自供给路径一致：包内已有的文件不会被覆盖，缺失的由
romfs 种子补齐。

## config.json 关键项（实测值）

- `backend.isoPath: "sdmc:/TwilitRealm/Dusklight/The Legend of Zelda Twilight Princess.iso"`
- `backend.isoVerification: 0`（精简版 ISO 必须关校验）
- `backend.graphicsBackend: "vulkan"`、`backend.uiLanguage: 1`
- `game.disableShadows: true`、`game.internalResolutionScale: 4`
- Boost+ 生效证据（dusklight.log）：`[perf] boost tier=2 -> CPU 1785 / GPU 921 MHz / EMC 1600 MHz`
  （需 Switch 已装 sys-clk-OC；原厂系统会钳到 GPU 768）
