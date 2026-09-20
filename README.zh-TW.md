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
| `make cocotb` | 執行 Python (cocotb) 測試平台。 | `build/cocotb-results.xml` |
| `make synth` | 使用 Yosys 將 RTL 進行電路合成。 | `build/synthesis.json` |
| `make gatesim` | 對合成後的 netlist 重跑一次模擬，需先執行 `make gds`。 | `終端機輸出` |
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

### 用 Python 寫測試平台

`make cocotb` 執行 [cocotb](https://www.cocotb.org/) 測試：用 Python coroutine
驅動同一份 RTL，底層是同一個模擬器。它是 `test/tb_blinky.v` 的另一種選擇，不是
取代——哪種語言適合這個測試就用哪種。

```bash
make cocotb
```

`test/test_blinky_cocotb.py` 這個範例展示的是 Python 在這裡明顯佔優的一件事：
直接寫入設計**內部**的訊號。

```python
dut.count.value = (1 << (WIDTH - 1)) - 1   # 停在翻轉前一拍
await tick(dut)
assert dut.led.value == 1
```

用這個方式驗證「led 就是計數器最高位元」只需要四個 cycle。Verilog testbench 要
做到同一件事，只能覆寫 `WIDTH`（閘級 testbench 做不到），或是老實跑完 2^25 個
cycle——也就是下面 `make gatesim` 花四分鐘在做的事。

範例裡還記下一個容易踩的坑：`RisingEdge` 是在時脈邊緣**當下**恢復執行，此時
non-blocking assignment 還沒生效。所以檔案裡每次讀值前都再等一個 `Timer`，否則
讀到的是上一個 cycle 的值。

### 模擬閘級電路，而不只是 RTL

`make sim` 驗證的是你寫的 Verilog，它並不能證明工具從中產生的 netlist 也對。
latch 被誤推斷、reset 處理方式、合成器如何解讀有歧義的 `always` 區塊——這些都
夾在兩者之間，而且從 RTL 看不出來。`make gatesim` 補上這一段：它拿 `make gds`
留下的閘級 netlist（`build/runs/<tag>/final/nl/`），對著 Sky130 元件自己的
Verilog model 跑模擬。

```bash
make gds       # 產生 netlist
make gatesim   # 模擬它
```

它需要自己的 testbench，放在 `test/gate/`，因為合成會把參數固定下來：
`test/tb_blinky.v` 靠把 `WIDTH` 設成 4 來縮小設計，而 netlist 裡已經沒有
`WIDTH` 可以設。因此 `test/gate/tb_blinky_gl.v` 只驅動真正的接腳，並觀察 `led`
走完一個完整的除頻週期——整整 2^26 個 cycle，大約需要四分鐘（CI runner 上實測 3 分 36 秒）。

這個代價就是為什麼 CI 只在推送到 `main` 與 `v*` tag 時跑 `make gatesim`，而不
是每個 pull request 都跑。

### 在容器內開發

本專案附有 [Dev Container](https://containers.dev/)。用 GitHub Codespaces 開啟，或在 VS Code 選擇「在容器中重新開啟」，即可取得與 CI 相同的映像檔，Verilog 相關擴充套件也已裝好——不必手動輸入任何 Docker 指令。`Makefile` 會偵測到自己已在容器內，直接呼叫工具，而不會再疊一層容器。

容器內以 `root` 執行。在 Linux 主機上，這代表它寫進 `build/` 的檔案擁有者會是 `root`，從主機執行 `make clean` 可能需要 `sudo`。改用一般使用者會讓 Codespaces 無法連線，所以我們選擇承受這個代價。

`make gds` 在這裡面也能跑。它以 sidecar 的方式啟動 LibreLane 容器，因此 Dev Container 內建了一個自己的 Docker daemon 供它使用——不必再退回主機終端機，而在 Codespaces 上，那原本代表你根本無法執行這個招牌指令。

這裡用的是 docker-**in**-docker 而不是 docker-outside-of-docker，兩者的差別不是偏好問題。`make gds` 會把工作目錄 bind-mount 進去，而在容器內那是 `/workspace`。外部 daemon 會把這個路徑解析到你的主機上，那裡並沒有 `/workspace`，於是 Docker 會建立一個空目錄，LibreLane 就對著空氣跑——不會報錯，只會在流程深處出現一個令人困惑的失敗。內部 daemon 則解析到這個容器的檔案系統，那裡就是你的專案。

代價是第一次執行要在容器內拉一次 LibreLane 映像檔，而且 Dev Container 需要重建一次才會裝上這個 feature。如果 `make gds` 說它找不到 Docker daemon，它要的就是一次重建。

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
│   ├── tb_blinky.v              # RTL 模擬 (make sim)
│   ├── test_blinky_cocotb.py    # Python 測試平台 (make cocotb)
│   └── gate/                    # 閘級模擬 (make gatesim)
│       └── tb_blinky_gl.v
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
