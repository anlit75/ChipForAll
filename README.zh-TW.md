<div align="center">

# ChipForAll

**Write Verilog. Prove it Works. Get a Chip Layout.**

一個模板，有真的會失敗的測試、完整的 RTL 到 GDSII 流程，每個 commit 還有一個結果網頁。它在瀏覽器裡的 GitHub Codespace 執行。一個 EDA 工具都不用裝。

[**Use this template**](https://github.com/anlit75/ChipForAll/generate) · [**看一個真實結果**](https://anlit75.github.io/ChipForAll/) · [指南](docs/guide.zh-TW.md) · [English](README.md)

![測試通過，改一行後四個測試失敗，make gds 一步步做出版圖，CI 發布結果網頁](https://raw.githubusercontent.com/anlit75/c4o-core/assets/demo/demo.gif)

[![CI Status](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml/badge.svg)](https://github.com/anlit75/ChipForAll/actions/workflows/verify.yml)
[![release Version](https://img.shields.io/github/v/release/anlit75/ChipForAll?label=version)](https://github.com/anlit75/ChipForAll/releases)
[![License](https://img.shields.io/github/license/anlit75/ChipForAll)](LICENSE)
[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anlit75/ChipForAll)

</div>

## 快速開始

你需要一個 GitHub 帳號。其他的都在 Codespace 裡跑。個人帳號每月有[免費額度](https://docs.github.com/en/billing/concepts/product-billing/github-codespaces#free-quota)。

| 步驟 | 時間或大小 |
|---|---|
| `make sim` | 約 7 秒 |
| `make gds`，blinky 的流程 | 約 2 分鐘 |
| `make gds`，只有第一次：LibreLane 映像檔 | 約 1.5 GB |
| `make gds`，只有第一次：PDK | 約 170 MB，磁碟上約 1 GB |

**1. 做一份自己的副本。** 按 [**Use this template → Create a new repository**](https://github.com/anlit75/ChipForAll/generate)。取個名字，再按 **Create repository**。

**2. 在你的副本開一個 Codespace。** 在你的新 repo 按 **Code → Codespaces → Create codespace on main**。第一次啟動要幾分鐘。如果 VS Code 問你是否信任這些檔案的作者，按 **Trust Folder & Continue**。等到終端機出現。

<details>
<summary>第一次用 GitHub？看每一步怎麼點。</summary>

![建立名為 my-chip 的副本，在上面開 Codespace，信任資料夾，再跑 make sim，5 個測試全部通過](https://raw.githubusercontent.com/anlit75/c4o-core/assets/demo/tutorial.gif)

</details>

**3. 確認測試通過**（幾秒鐘）。在終端機輸入：

```bash
make sim
```

`make sim` 先檢查 RTL，再跑 `config.yaml` 列出的每個測試。只打 `make` 只會檢查設定。

**4. 故意把它改壞。** 把 `rtl/blinky.v` 裡的 `count[WIDTH-1]` 改成 `count[WIDTH-2]`。LED 的閃爍會快一倍。這仍是合法的 Verilog，所以 RTL 檢查會通過。只有測試看得出行為不對。再跑一次 `make sim`：

```
c4o sim · blinky · c4o-core 2.30.0
  ✓ rtl     verilator, no warnings · yosys 0.33, 54 cells · 0.5 s
  ✓ check   tests configured · 0.3 s
  – verilog skipped: TEST_FILES is not set
  ✗ cocotb  4 of 5 tests failed · seed 1793447982 · 3.3 s
[ERROR] cocotb tests failed: led_rises_half_a_period_after_reset, led_toggles_with_a_full_period, reset_in_the_middle_restarts_the_count, random_resets_match_the_model

led_rises_half_a_period_after_reset  tb/test_blinky_cocotb.py:81
led was 1 after 32767 cycles, expected 0: it should rise at cycle 32768
rerun this test:
make cocotb SEED=1793447982 TEST=test_blinky_cocotb.led_rises_half_a_period_after_reset
```

`rtl` 那行通過，`cocotb` 那行失敗。cocotb 是 Python 函式庫，`tb/` 裡的測試就是用它寫的，所以這一行就是你的測試。

`c4o` 是工具鏈映像檔 c4o-core 的名字，`make` 就是用它來執行。

`[ERROR]` 那行指出哪些測試失敗。它下面，每個失敗的測試會印出自己的訊息，接著是 `rerun this test:` 和只重跑它的指令。這個區塊只列出四個中的第一個。最後幾行寫出完整的記錄 `build/log/cocotb.log`、幾個測試失敗，和下一步該做什麼。`make` 回傳非零，所以 CI 也會失敗。用 `git checkout -- rtl/blinky.v` 還原。[幫你的設計寫這種測試 →](docs/guide.zh-TW.md#幫你自己的設計寫測試平台)

**5. 做出版圖**（約 2 分鐘，加上第一次的下載）：

```bash
make gds
```

最後它會告訴你做出了什麼：

```
  blinky: signoff clean, timing met, no lint warnings

  setup slack        +5.96 ns  (0 violations)
  hold slack         +0.11 ns  (0 violations)
  signoff            clean  (DRC, LVS, antenna, XOR)
  layout             runs/blinky_run/final/render/blinky.png

  GDS         build/blinky.gds
  Stages      build/stages/ (6 renders)
```

這是精簡版。第一行總結了下面各列。`signoff clean` 加上正的 slack，代表版圖通過了製造檢查，也滿足時脈。流程到這個 GDS 檔為止：下線製造不在這個 repo 的範圍內。[完整輸出和每一行怎麼讀 →](docs/guide.zh-TW.md#看懂執行結果)

想在自己的電腦跑？[用 Docker 跑 →](docs/guide.zh-TW.md#在自己的電腦上跑)

## 線上結果網頁

`main` 上每次 CI 都會把結果網頁發佈到 `https://<you>.github.io/<your-repo>/`。[這是這個模板的結果網頁。](https://anlit75.github.io/ChipForAll/)

頁面最前面是你的版圖。可以用 3D 開啟，也可以下載 GDS。接著是測試、覆蓋率、時序、面積、功耗和 signoff。這些區塊都可以展開 History，看 `main` 上歷次 commit 的圖表。最後一節 How it was built 為每個階段各放一張真實的圖。

只要開一次：**Settings → Pages → Source: GitHub Actions**。本機用 `make site` 產生這個網頁。[更多 →](docs/guide.zh-TW.md#發佈結果網頁)

## 換成你的設計

刪掉 blinky 的檔案。Verilog 放 `rtl/`，測試放 `tb/`。在 `config.yaml` 列出它們。把 `DESIGN_NAME` 設成你的頂層模組。其他資料 `Makefile` 和 CI 都從那個檔案讀。[必須一致的三件事 →](docs/guide.zh-TW.md#換成你自己的設計)

要改設計需要[一點 Verilog](docs/guide.zh-TW.md#開始之前)。你的設計能動之後，把這份 README 換成介紹你自己設計的版本。

## 指令

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
| `make info` | 印出 c4o-core、映像檔和各工具的版本。貼進 bug 回報 |
| `make clean` | 刪除 `build/`。保留 `runs/`，因為 `make report` 和 `make gatesim` 會讀它 |

上次 `make gds` 之後如果你的 RTL 改了，`make gatesim` 和 `make report` 會報錯並停下來。再跑一次 `make gds`。

`make help` 列出全部指令。[完整表格](docs/guide.zh-TW.md#指令)列出每個指令的產出。

有東西失敗了？[出問題的時候](docs/guide.zh-TW.md#出問題的時候)列出該怎麼做。

## 你會得到什麼

它適合想要第一顆拿得出手的晶片的學生與自學者，也適合正在學驗證的人。完整的 UVM 風格環境請看 [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)，它就是從這個模板建出來的。

用開源流程產出一份版圖，[LibreLane](https://github.com/librelane/librelane) 已經做得到。但它不會告訴你那份版圖**對不對**，這個問題還沒解決。ChipForAll 補上缺的那一塊：流程周圍的測試、檢查和 CI。

- **真的會失敗的測試。** Verilog 與 Python（cocotb）測試平台，設計壞了就回傳非零。
- **閘級模擬。** 在合成產出的 netlist 上重跑你的測試。latch 和 reset 的 bug 就藏在那裡。
- **看得懂的 signoff。** 一份簡短的摘要列出面積、時序、功耗和 DRC/LVS。不用去讀有好幾百個 key 的 JSON。
- **不用裝任何 EDA 工具。** 全部都在一個 Docker 映像檔裡。Docker、Dev Container 和 Codespace 的指令都一樣。
- **成果可以公開。** Sky130 是 Apache 2.0，沒有 NDA。GDS 可以直接放進作品集。簽了 foundry NDA 的工程師可以多一份能公開的成果。

這裡用的是商用工具的開源對應。Icarus 對 VCS，Yosys 對 Design Compiler，OpenSTA 對 PrimeTime。流程和詞彙轉得過去。工具名稱轉不過去。[完整對照 →](docs/guide.zh-TW.md#這個專案是什麼不是什麼)

## 延伸閱讀

- [指南](docs/guide.zh-TW.md)：在自己的電腦上跑、寫測試平台、除錯用波形、閘級模擬、slack 為負時、設定參考
- [c4o-core](https://github.com/anlit75/c4o-core)：每個指令背後的工具鏈引擎
- [c4o-pyuvm](https://github.com/anlit75/c4o-pyuvm)：跑在真實 UART 上的 pyuvm 驗證環境

---

<div align="center">

由 Ting-An Cheng（[@anlit75](https://github.com/anlit75)）維護。早期專案，歡迎開 issue。

[MIT License](LICENSE) · Powered by [c4o-core](https://github.com/anlit75/c4o-core)

</div>
