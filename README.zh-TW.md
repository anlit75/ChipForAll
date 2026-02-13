# ⚡ ChipForAll (C4O)

![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)
![License](https://img.shields.io/github/license/anlit75/ChipForAll)
![c4o-core:v1.1.1](https://img.shields.io/badge/c4o--core-v1.1.1-blue)

## 1. 簡介
**ChipForAll** 是一個 **即時開源晶片設計模板 (Instant Open Source Chip Design Template)**。它提供了一個可直接生產的數位邏輯設計環境 (Verilog)，免去了安裝複雜 EDA 工具的煩惱。

本專案的核心是 **[c4o-core](https://github.com/anlit75/c4o-core)** 引擎——這是一個整合了 Yosys, Verilator, Icarus Verilog 和 Volare 的 Docker 容器。這意味著你可以專注於你的 RTL 設計，而不必擔心工具鏈的設定問題。

---

## 2. 環境需求

唯一的必要條件是 **Docker** (Desktop 或 Engine)。不需要在本機安裝任何 EDA 工具。

*   **推薦配置**: [VS Code](https://code.visualstudio.com/) + [DevContainers 擴充套件](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)，可實現一鍵式環境搭建。

---

## 3. 快速開始 (Happy Path)

1.  **複製專案 (Clone)**:
    ```bash
    git clone https://github.com/anlit75/ChipForAll.git
    cd ChipForAll
    ```

2.  **設定你的設計**:
    編輯專案根目錄下的 `config.json` 來指向你的 Verilog 檔案。
    *(預設已配置為使用 `src/blinky.v`)*

3.  **安裝 PDK (Sky130)**:
    此步驟會下載並在專案資料夾內安裝 SkyWater 130nm 製程設計套件 (由 `volare` 管理)。
    ```bash
    make pdk
    ```

4.  **建置與驗證**:
    一次執行語法檢查 (Lint)、模擬 (Sim) 與合成 (Synth)。
    ```bash
    make all
    ```

5.  **實體設計 (GDSII)**:
    使用 OpenLane 產生最終的晶片佈局。
    ```bash
    make gds
    ```
    *產出檔案: `build/blinky.gds`*

---

## 4. 專案結構

```text
.
├── config.json       # 專案設定檔 (根目錄) - 定義設計名稱、原始碼路徑、PDK 等
├── Makefile          # 主要入口點 (封裝了 c4o-core 和 OpenLane 的 Docker 指令)
├── src/              # RTL 原始碼
│   └── blinky.v      # 範例：一個簡單的 LED 閃爍電路
├── test/             # Testbenches (測試平台)
│   └── tb_blinky.v   # 範例：驗證 blinky 模組
└── build/            #產出物 (模擬波形、GDS、網表)
    ├── sim.vvp       # 編譯後的模擬檔
    ├── synthesis.json # 合成後的網表
    └── blinky.gds    # 最終 GDSII 佈局檔
```

---

## 5. 指令參考 (Commands Reference)

| 目標 (Target) | 說明 | 使用工具 |
| :--- | :--- | :--- |
| `make lint` | 檢查 Verilog 語法錯誤 | **Verilator** |
| `make sim` | 執行行為級模擬 | **Icarus Verilog** |
| `make synth` | 將 RTL 合成為邏輯閘層級網表 | **Yosys** |
| `make pdk` | 下載並啟用 Sky130 PDK | **Volare** |
| `make gds` | 執行完整的 RTL-to-GDSII 流程 | **OpenLane** |
| `make clean` | 移除所有建置產出物 (`build/`) | `rm` |
| `make shell` | 進入互動式 c4o-core Shell | **Bash** |

---

## 6. VS Code DevContainer (推薦使用)

本專案包含 `.devcontainer` 設定。如果你在 VS Code 中開啟此資料夾，系統會提示你「Reopen in Container」。這樣做將會提供一個預先配置好的環境，包含：

*   **波形檢視器**: 使用 **WaveTrace** 擴充套件直接在 VS Code 中查看 `.vcd` 檔案。
*   **電路圖檢視器**: 使用 **Yosys Viewer** 視覺化你的網表。
*   **語法高亮**: 內建完整的 Verilog 支援。

Maintained by [anlit75](https://github.com/anlit75).
