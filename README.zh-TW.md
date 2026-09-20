# ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

**專為開源晶片設計打造的「零配置」入門套件。** 專注於 Verilog 開發，不再為環境變數煩惱。

## ✨ 特色

* **🐳 Docker 化環境**：無需手動安裝 Yosys、Verilator 或 LibreLane。只要有 Docker，一切就緒。
* **⚡ 零配置**：只需複製（Clone）此儲存庫即可執行。環境已預先針對 Skywater 130nm PDK 完成配置。
* **🛠 全流程支援**：只需指令一次，即可完成從 Verilog RTL 到 GDSII 佈局（Layout）的所有步驟。
* **✅ CI/CD**：包含 GitHub Actions 工作流，在每次 Push 時自動驗證您的設計。

## 🚀 快速啟動

### 前置作業
* Docker (Desktop 或 Engine)
* Make
* Git

### 1. 複製儲存庫
```bash
git clone https://github.com/anlit75/ChipForAll.git
cd ChipForAll
```

### 2. 執行完整流程

將 Verilog 程式碼轉換為最終的 GDSII 佈局檔案：

```bash
make gds

```

*請稍等幾分鐘。系統將自動下載 PDK、執行電路合成（Synthesis）、佈局繞線（Place & Route）並產出佈局檔案。*

## 📖 使用指南

我們提供統一的 `Makefile` 來處理所有事務。

| 指令 | 說明 | 輸出路徑 |
| --- | --- | --- |
| `make lint` | 使用 Verilator 檢查 Verilog 語法錯誤。 | `終端機輸出` |
| `make sim` | 使用 Icarus Verilog 執行模擬。 | `build/sim.vvp` |
| `make synth` | 使用 Yosys 將 RTL 進行電路合成。 | `build/synthesis.json` |
| `make gds` | 使用 LibreLane 產生實體佈局。 | `build/<DESIGN_NAME>.gds` |
| `make report` | 顯示上次 `make gds` 的面積、時序與功耗。 | `終端機輸出` |
| `make shell` | 進入 c4o-core 容器的互動式 shell。 | `N/A` |
| `make clean` | 清除所有產出的檔案。 | `N/A` |

> **💡 注意：** 首次執行 `make gds` 時，系統會自動下載並安裝 Sky130 PDK（約 3GB）。請耐心等候！

### 看懂執行結果

`make gds` 結束時會直接印出這次流程量到的數字，不必自己去翻檔案：

```
  blinky

  die              100 x 100 um  (10000 um^2)
  utilization      29.2%
  standard cells   243
  setup slack      +4.69 ns  (0 violations)
  hold slack       +0.11 ns  (0 violations)
  power            0.292 mW
  lint warnings    441
```

slack 為正值代表設計滿足 `config.yaml` 裡設定的時脈。想再看一次而不重跑整個
流程，單獨執行 `make report` 即可。

### 在容器內開發

本專案附有 [Dev Container](https://containers.dev/)。在 VS Code 選擇「在容器中重新開啟」，即可取得與 CI 相同的映像檔，Verilog 相關擴充套件也已裝好——不必手動輸入任何 Docker 指令。`Makefile` 會偵測到自己已在容器內，直接呼叫工具，而不會再疊一層容器。

`make gds` 是唯一的例外：它要啟動 LibreLane 容器，而 Dev Container 內沒有 Docker socket。這一項請在**主機終端機**執行；若忘記，Makefile 會提醒你。

習慣用自己的編輯器？`make shell` 可以從任何終端機進入同一個映像檔。

## 📂 專案架構

```text
.
├── .devcontainer/     # 🐳 VS Code Dev Container 定義
├── config.yaml        # ⚙️ 專案配置 (設計名稱、時序、面積)
├── Makefile           # 🎮 指令控制中心
├── src/               # ✍️ 您的 Verilog
│   └── blinky.v
├── test/              # 🧪 您的測試平台 (Testbenches)
│   └── tb_blinky.v
└── build/             # 📦 所有產出的檔案 (GDS, Logs, Netlists)
```

## 📝 配置設定

修改根目錄下的 `config.yaml` 來變更您的設計設定。它是一份 [LibreLane](https://github.com/librelane/librelane) 配置檔——同一個檔案同時驅動模擬與實體設計流程，檔案內的註解標示了哪些設定是您通常會改的：

```yaml
DESIGN_NAME: my_design

VERILOG_FILES:
  - dir::src/my_design.v

# 僅供模擬使用。LibreLane 會忽略以 '//' 開頭的 key。
"//TEST_FILES":
  - dir::test/*.v

CLOCK_PORT: clk
CLOCK_PERIOD: 10.0
```

檔案中其餘的 key（`PDK`、`DIE_AREA`、`FP_SIZING`…）用於設定實體設計流程。在需要之前請保持原樣——若缺少任何一項，`make gds` 會告訴您。

---

由 **[c4o-core](https://github.com/anlit75/c4o-core)** 引擎驅動。
