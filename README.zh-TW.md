<div align="center">

# ChipForAll

**一個讓晶片設計自己證明它是對的模板。用開源工具，一個指令就好。**

寫 Verilog。用真的會失敗的測試證明它是對的。每個 commit 都拿到一份真正的晶片版圖和一個結果網頁。所有 EDA 工具都包在一個 Docker 映像檔裡，一個都不用自己裝。

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

[**線上結果網頁**](https://anlit75.github.io/ChipForAll/) · [快速開始](#-快速開始) · [指南](docs/guide.zh-TW.md) · [English](README.md)

![測試通過，改一行後四個測試失敗，make gds 一步步做出版圖，CI 發布結果網頁](https://raw.githubusercontent.com/anlit75/c4o-core/assets/demo/demo.gif)

</div>

---

## 為什麼是 ChipForAll

用開源流程產出一份版圖，[LibreLane](https://github.com/librelane/librelane) 已經做得到。但它不會告訴你那份版圖**對不對**。ChipForAll 補上缺的那一塊：流程周圍的測試、檢查和 CI。

| | |
|---|---|
| 🧪 **真的會失敗的測試** | Verilog 與 Python（cocotb）測試平台，設計壞了就回傳非零。 |
| 🔬 **閘級模擬** | 在合成產出的 netlist 上重跑你的測試。latch 和 reset 的 bug 就藏在那裡。 |
| 📊 **看得懂的 signoff** | 一份簡短的摘要列出面積、時序、功耗和 DRC/LVS。不用去讀有好幾百個 key 的 JSON。 |
| 🌐 **每個 commit 一個結果網頁** | CI 把版圖、測試、時序、面積、功耗和 signoff 發佈到 GitHub Pages。 |
| 🐳 **不用裝任何 EDA 工具** | 全部都在一個 Docker 映像檔裡。可以從 Docker、Dev Container 或 Codespace 執行。三種環境的指令都一樣。 |
| 🔓 **成果可以公開** | Sky130 是 Apache 2.0，沒有 NDA。GDS 可以直接放進作品集。 |

## 🚀 快速開始

你需要 Docker、Make 和 Git。Codespace 裡三樣都有：

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/anlit75/ChipForAll)

這個按鈕開的永遠是原始的 `anlit75/ChipForAll`，從你副本裡的這份 README 點也一樣。拿來試第 2、3 步就夠了。想保留成果、擁有自己的 CI 和結果網頁，就先做第 1 步。然後從你的副本開 Codespace（**Code → Codespaces**）。兩種情況都要選比最小規格大的機型，因為 `make gds` 需要磁碟空間。[原因 →](docs/guide.zh-TW.md#在容器內開發)

Apple Silicon 也能用，但有些指令會走模擬。[是哪些 →](docs/guide.zh-TW.md#開始之前)

**1. 做一份自己的副本。** 按 **Use this template → Create a new repository**。然後 clone 下來：

```bash
git clone https://github.com/<you>/<your-repo>.git && cd <your-repo>
```

在 Codespace 裡 repo 已經在了。不用 clone。

**2. 確認測試通過**（幾秒鐘）：

```bash
make sim
```

`make sim` 先檢查 RTL，再跑 `config.yaml` 列出的每個測試。只打 `make` 只會檢查設定。

**接著故意把它改壞。** 這一步是版圖工具做不到的。把 `rtl/blinky.v` 裡的 `count[WIDTH-1]` 改成 `count[WIDTH-2]`。LED 的閃爍會快一倍。再跑一次 `make sim`：

```
  FAIL cocotb  1 passed, 4 failed, seed 1791638899, 10.0 s
[ERROR] cocotb tests failed: led_rises_half_a_period_after_reset, led_toggles_with_a_full_period, reset_in_the_middle_restarts_the_count, random_resets_match_the_model

led_rises_half_a_period_after_reset  tb/test_blinky_cocotb.py:64
AssertionError: led rose before cycle 32768
assert 1 == 0
make cocotb SEED=1791638899 TEST=test_blinky_cocotb.led_rises_half_a_period_after_reset
```

`[ERROR]` 那行指出哪些測試失敗。它下面，每個失敗的測試會印出自己的訊息，和只重跑它的指令。這個區塊只列出四個中的第一個。`make` 回傳非零，所以 CI 也會失敗。用 `git checkout -- rtl/blinky.v` 還原。[幫你的設計寫這種測試 →](docs/guide.zh-TW.md#幫你自己的設計寫測試平台)

**3. 做出版圖**（幾分鐘。第一次還要下載好幾 GB 的 PDK）：

```bash
make gds
```

最後它會告訴你做出了什麼：

```
  blinky

  die                56.375 x 67.095 um  (3782.48 um^2)
  utilization        51.7%
  instances          65 after synthesis, 116 after routing
  instance classes   32 logic, 27 well taps, 21 timing-repair buffers, 17 inverters, 16 sequential, 3 clock buffers
  drive strength     X1 0->17, X2 65->69, X16 0->3  (synthesis->routing)
  setup slack        +5.96 ns  (0 violations)
  hold slack         +0.11 ns  (0 violations)
  limit violations   0 max slew, 0 max capacitance, 0 max fanout
  power              0.143 mW  (nom_tt_025C_1v80)
  signoff            clean  (DRC, LVS, antenna, XOR)
  lint warnings      0
  layout             runs/blinky_run/final/render/blinky.png

  GDS         build/blinky.gds
  Stages      build/stages/ (6 renders)
```

`signoff clean` 加上正的 slack，代表版圖通過了製造檢查，也滿足時脈。流程到這個 GDS 檔為止：下線製造不在這個 repo 的範圍內。[每一行怎麼讀 →](docs/guide.zh-TW.md#看懂執行結果)

## 🌐 結果直接上線

`main` 上每次 CI 都會把結果網頁發佈到 `https://<you>.github.io/<your-repo>/`。頁面最前面是你的設計版圖，可以用 3D 開啟，也可以下載 GDS。接著是判定和測試，然後是程式碼覆蓋率、時序、面積與 instance、功耗，以及 signoff。最後一節 How it was built 為每個階段各放一張真實的圖，點一列會展開它的說明。頁面上會寫建置時間和對應的 commit。除了最後一節，每個區塊可以展開 History，看 `main` 上歷次 commit 的圖表。每個區塊最後也列出它背後的檔案，可以下載。

只要開一次：**Settings → Pages → Source: GitHub Actions**。本機用 `make site` 產生這個網頁。[更多 →](docs/guide.zh-TW.md#發佈結果網頁)

## 🎮 指令

| 指令 | 做什麼 |
|---|---|
| `make` | 檢查 `config.yaml` 和它列出的檔案。不執行任何工具 |
| `make rtl` | 編譯、lint 和合成你的 RTL：幾秒內跑完的步驟 |
| `make sim` | 先做 `make rtl`，再跑每個測試：Verilog 和 Python（cocotb）。加上 `WAVES=1` 也會寫出波形 |
| `make regress` | 你的測試清單，每個測試跑多個 seed，然後量程式碼覆蓋率。`COVERAGE=0` 會跳過覆蓋率。[更多 →](docs/guide.zh-TW.md#多個-seed) |
| `make gds` | 完整 RTL 到 GDSII 流程，最後印出上面的摘要。輸入沒變時會跳過流程，`FORCE=1` 強制執行 |
| `make gatesim` | 在閘級電路上重跑你的測試（`make gds` 之後） |
| `make report` | 不重跑，再印一次摘要（`make gds` 之後） |
| `make site` | 結果網頁，產在 `build/site/` |
| `make shell` | 進到工具鏈容器裡的 shell |

上次 `make gds` 之後如果你的 RTL 改了，`make gatesim` 和 `make report` 會報錯並停下來。再跑一次 `make gds`。

`make help` 列出全部指令。[完整表格](docs/guide.zh-TW.md#指令)列出每個指令的產出。

## ✍️ 換成你的設計

刪掉 blinky 的檔案。Verilog 放 `rtl/`，測試放 `tb/`。在 `config.yaml` 列出它們。把 `DESIGN_NAME` 設成你的頂層模組。其他資料 `Makefile` 和 CI 都從那個檔案讀。[必須一致的三件事 →](docs/guide.zh-TW.md#換成你自己的設計)

## 適合誰

- **學生與自學者**：想要第一顆拿得出手的晶片，而且有測試證明它是對的。要改設計需要[一點 Verilog](docs/guide.zh-TW.md#開始之前)。
- **簽了 foundry NDA 的工程師**：想要一份可以公開的第二份成果。
- **正在學驗證的人**：完整的 UVM 風格環境請看 [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)，它就是從這個模板建出來的。

**先說清楚：** 這裡用的是商用工具的開源對應。Icarus 對 VCS，Yosys 對 Design Compiler，OpenSTA 對 PrimeTime。流程和詞彙轉得過去。工具名稱轉不過去。[完整對照 →](docs/guide.zh-TW.md#這個專案是什麼不是什麼)

## 📚 延伸閱讀

- [指南](docs/guide.zh-TW.md)：前置條件、寫測試平台、除錯用波形、閘級模擬、slack 為負時、設定參考
- [c4o-core](https://github.com/anlit75/c4o-core)：每個指令背後的工具鏈引擎
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)：跑在真實 UART 上的 pyuvm 驗證環境

---

<div align="center">

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
