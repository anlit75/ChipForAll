# 🚀 ChipForAll (C4O) 

ChipForAll 是一個 **「零配置 (Zero-Config)」** 的開源晶片設計模板。
別再為了安裝工具鏈浪費時間，現在就開始設計你的晶片。

核心由 **c4o-core** 引擎驅動。

## ✨ 特色功能

*   **🐳 Docker化環境**: 不需要手動安裝 Yosys, Verilator 或 OpenLane。只要有 Docker，你就準備好了。
*   **⚡ 零配置**: 只要 Clone 專案並執行。環境已經預先針對 Skywater 130nm PDK 設定好了。
*   **🛠 全流程支援**: 一個指令即可完成從 Verilog RTL 到 GDSII 佈局的全部流程。
*   **✅ CI/CD 就緒**: 內建 GitHub Actions 流程，每次 Push 自動驗證你的設計。

---

## 🏁 快速開始 (Quick Start)

### 環境需求 (Prerequisites)
*   Docker (Desktop 或 Engine)
*   Make
*   Git

### 1. 複製專案 (Clone the Repo)
```bash
git clone https://github.com/anlit75/ChipForAll.git
cd ChipForAll
```

### 2. 執行全流程 (Run the Full Flow)
從 Verilog 程式碼產生最終的 GDSII 佈局檔：
```bash
make gds
```
*請稍候幾分鐘。系統將會自動下載 PDK，執行合成、佈局繞線，並產生佈局檔。*

---

## 📖 使用指南 (Usage Guide)

我們提供了一個統一的 `Makefile` 來處理所有事情。

| 指令 | 說明 | 輸出位置 |
|---|---|---|
| `make lint` | 使用 Verilator 檢查 Verilog 語法錯誤。 | 終端機輸出 |
| `make sim` | 使用 Icarus Verilog 執行模擬。 | `build/sim.vvp` |
| `make synth` | 使用 Yosys 將 RTL 合成為邏輯閘。 | `build/synthesis.json` |
| `make gds` | 使用 OpenLane 產生實體佈局。 | `build/blinky.gds` |
| `make clean` | 移除所有產出的檔案。 | N/A |

> **💡 注意:** 第一次執行 `make gds` 時，系統會自動下載並安裝 Sky130 PDK (約 3GB)。請耐心等待！

---

## 📂 專案結構

```text
.
├── config.json        # ⚙️ 專案設定檔 (設計名稱, 時脈, 面積)
├── Makefile           # 🎮 指令控制中心
├── src/               # ✍️ 你的 Verilog
│   └── blinky.v
├── test/              # 🧪 你的測試平台 (Testbenches)
│   └── tb_blinky.v
└── build/             # 📦 所有產出物 (GDS, Logs, Netlists)
```

---

## 📝 設定 (Configuration)

修改根目錄下的 `config.json` 來變更你的設計設定：

```json
{
  "DESIGN_NAME": "my_design",
  "VERILOG_FILES": ["src/my_design.v"],
  "CLOCK_PERIOD": 10.0
}
```

Happy Hacking! 🛠️
