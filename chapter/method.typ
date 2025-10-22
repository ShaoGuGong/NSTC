#import "@preview/lovelace:0.3.0": *

= 研究方法
    == 探討各式自我排程策略執行 PBT 任務的效能及影響因素，並提出新的策略
    本研究針對當前主流分散式計算技術的挑戰，
    提出一套創新的資源優化自我排程方法。
    此方法旨在充分發揮異質叢集中所有節點的潛在計算效能，
    並在維持模型精度的前提下，
    有效縮短整體訓練所需時間。
    我們的研究建立在主流分散式框架 Ray 及其超參數優化套件 Ray Tune 之上，
    對其核心排程機制進行了深度改良。

    Ray Tune 的原始設計主要針對硬體規格一致的同質性環境，
    它會對每個計算節點（Worker）指派等量的試驗（Trial）負載。
    然而，在現實中由不同時期採購、規格各異的硬體所組成的異質性環境中，
    這種均等分配策略會導致嚴重的效能瓶頸。
    性能較弱的節點因無法及時完成任務，
    其計算結果的提交時間遠遠落後於高性能節點，
    從而引發「陳舊度」（Staleness）問題。
    此問題不僅拖累整體訓練效率，
    更會因進度不同步而干擾 PBT 等先進優化算法的運作，
    造成資源的極大浪費。

    為了解決此困境，
    我們設計了一套基於節點實際性能的動態任務分配機制。
    此機制會依據各節點的計算能力來彈性調整其承接的試驗數量，
    即高性能節點承擔更多任務，
    低性能節點則減少負擔。
    此外，為進一步緩解陳舊度造成的影響，
    我們引入了分層訓練策略：
    將訓練初期、代數較低的試驗優先分配給高性能節點，
    而將代數較高的試驗交由性能較弱的節點處理。
    這種方法不僅優化了資源利用率，
    也促進了節點間的負載均衡，
    從而達成更高效的動態排程。
    本章將從三個層面詳細闡述我們提出的策略：
    \1\. 初始化的靜態資源評估，
    \2\. 動態資源調整策略， 以及
    \3\. 陳舊度問題的應對方案。

        === 初始化的靜態資源評估
        在超參數優化任務正式啟動前，
        為了建立一個可靠的初始任務分配基準，
        我們提出了一種基於效能分數（Performance Score）的評估方法。
        此方法透過量化公式評估各節點的計算能力，
        並根據所得分數按比例分配初始的試驗數量。
        一個精準的初始分配，
        能有效避免在任務初期就產生嚴重的負載失衡，
        為後續的動態調整奠定良好基礎。
        我們設計了兩種核心評估指標：

        + *基於吞吐量的分數（Throughput-Based Score, TBS）:*
            此方法旨在量化節點處理特定深度學習工作負載的原始能力。
            我們透過一個基準測試來測量每個節點在單位時間內能夠完成的工作量，
            也就是其吞吐量。其核心概念由公式@TBS 定義：
            $
                italic("TBS") =
                frac(
                    italic("Workload") times italic("num_epochs"),
                    italic("total_time"),
                )
            $ <TBS>

        + *時間比率分數（Time-Ratio Score, TRS）:*
            此方法著重於節點間的相對執行效率，
            這在處理大量相似獨立任務（如 HPO 中的 Trial）時尤其關鍵。
            我們以叢集中完成單次試驗耗時最長的節點
            （最弱節點）作為參照基準，
            計算其他節點相對於此基準的效率倍數。
            一個節點完成任務的速度越快，
            其獲得的分數就越高，
            從而被賦予更多的初始試驗。
            該分數的計算方式如公式@TRS：
            $
                italic("TRS") =
                ceil(frac(
                    T_italic("weak"),
                    T_italic("current"),
                ))
            $ <TRS>

        === 動態資源調整策略
        僅有準確的初始分配並不足以應對整個訓練過程中的動態變化，
        例如剩餘試驗總數的減少或節點負載的波動。
        為此，我們設計了三種先進的動態調整策略，
        其虛擬碼分別展示於@algo-sra 、@algo-era 與@algo-eta ，
        以在訓練過程中持續優化資源分配與負載平衡：

        #[
            #set math.equation(numbering: none)
            #figure(
                kind: "algorithm",
                pseudocode-list(
                    booktabs: true,
                    numbered-title: [Stepwise Reduction Allocation (SRA)],
                )[
                    - *Input:* $"Nodes" = {"Node"_1 , dots , "Node"_n}$,
                        $n$: The total number of nodes.\
                        $Q = {Q_1 , dots , Q_n}$, $Q_i$:
                        The number of trials allocated.
                        $italic("Scores")_i$: Score for each node.
                    - *Output:* Updated trial allocations for each node.
                    + *for* each $"Node"_i$ in $"Nodes"$
                        + $ Q_i = italic("Scores")_i $
                    + *end*
                    + *while* stopping conditions not met
                        + $Delta = "stop_iteration" - "last_run_interval"$
                        + $ F = cases(
                            0.9^0 &"if" Delta < 300,
                            0.9^1 &"if" 300 <= Delta < 400,
                            0.9^2 &"if" 400 <= Delta < 500,
                            0.9^3 &"if" 500 <= Delta < 600,
                            0.9^4 &"if" 600 <= Delta < 700,
                            0.9^5 &"if" 700 <= Delta < 800,
                            0.9^6 &"if" Delta >= 800,
                        ) $
                        + *for* each $"Node"_i$ in $"Nodes"$
                            + $ Q_i = ceil(Q_i times F) $
                        + *end*
                    + *end*
                    + *return* Updated trial allocations.
                ],
            ) <algo-sra>
        ]

        === 陳舊度問題的應對方案
        在 PBT 這類演算法中，
        「陳舊度」是影響異質環境訓練效率的關鍵。
        當慢速節點的訓練結果（包含模型權重和超參數）嚴重滯後時，
        PBT 的 exploit 機制可能會用較新的、
        但可能較差的模型去覆蓋一個潛力巨大但尚未完成訓練的舊模型，
        從而損失了寶貴的探索成果。
        本研究的動態排程策略，
        透過主動管理節點間的訓練進度差異，
        有效緩解了此問題。
        我們的排程器不僅考量節點是否空閒，
        更會評估其當前任務的訓練代數。
        當高性能節點進度超前時，
        排程器會傾向於將代數較高的（即接近完成的）試驗分配給進度落後的節點，
        幫助它們「迎頭趕上」。
        這種「進度感知」（Progress-Aware）的任務分配方式，
        確保了各節點的訓練成果能夠更同步地參與到全局模型更新中，
        從而維持了數據的一致性與模型優化的有效性。

        #[
            #set math.equation(numbering: none)
            #figure(
                kind: "algorithm",
                pseudocode-list(
                    booktabs: true,
                    numbered-title: [Exponential Reduction Allocation (ERA)],
                )[
                    - *Input:* $"Nodes" = {"Node"_1 , dots , "Node"_n}$,
                        $n$: The total number of nodes.\
                        $Q = {Q_1 , dots , Q_n}$, $Q_i$:
                        The number of trials allocated.
                        $italic("Scores")_i$: Score for each node.\
                        $italic("Base")$: Base of reduction factor.
                    - *Output:* Updated trial allocations for each node.
                    + *for* each $"Node"_i$ in $"Nodes"$
                        + $ Q_i = italic("Scores")_i $
                    + *end*
                    + *while* stopping conditions not met
                        + $ x = ceil(
                            frac(
                                "stop_iteration" - "last_run_interval",
                                "intervals",
                            )
                        ) $
                        + *for* each $"Node"_i$ in $"Nodes"$
                            + $ Q_i = ceil(Q_i times italic("Base")^x) $
                        + *end*
                    + *end*
                    + *return* Updated trial allocations.
                ],
            ) <algo-era>
        ]

        #[
            #set math.equation(numbering: none)
            #figure(
                kind: "algorithm",
                pseudocode-list(
                    booktabs: true,
                    numbered-title: [Execution-Time Allocation (ETA)],
                )[
                    - *Input:* $"Nodes" = {"Node"_1 , dots , "Node"_n}$,
                        $n$: The total number of nodes.\
                        $Q = {Q_1 , dots , Q_n}$, $Q_i$:
                        The number of trials allocated.
                        $italic("Scores")_i$: Score for each node.\
                        $italic("Base")$: Base of reduction factor.
                    - *Output:* Updated trial allocations for each node.
                    + *for* each $"Node"_i$ in $"Nodes"$
                        + $ Q_i = italic("Scores")_i $
                    + *end*
                    + *while* stopping conditions not met
                            for all nodes
                            time $T_"weak"$
                        + *for* each $"Node"_i$ in $"Nodes"$
                                real-time performance ratio
                            + $ Q_i = ceil(T_"weak" / T_i) $
                        + *end*
                    + *end*
                    + *return* Updated trial allocations.
                ],
            ) <algo-eta>
        ]

    == 設計具 locality 與演化特性之兩階段自適應排程策略
        === 使用 Python Ray 當中的Actor 架構實現 Locality-Aware Scheduling
        我們將每個 Worker 封裝成獨立的 Actor，
        並依據其資源需求將其區分為僅 CPU Worker ($W_"cpu"$)
        與 GPU Worker ($W_"gpu"$)，
        以便針對不同的任務類型和資源配置進行精細化管理。
        這種分類方式不僅有助於提升資源利用效率，
        也能根據不同計算負載動態調整任務分配策略，
        確保系統在異質環境下仍能維持高效運行。

        每個 Worker 能夠保留自身的完整運算狀態，
        包括模型權重、已分配任務、訓練進度以及資源使用情況，
        從而確保即便在任務重新調度、節點暫時下線或系統意外中斷的情況下，
        訓練仍能從先前進度無縫延續。
        這種狀態保留機制對長時間或高頻率更新的深度學習模型訓練尤其重要，
        能夠有效避免重複計算、減少不必要的資料傳輸，
        並提升整體系統的運算效率與穩定性。

        此外，Worker 的設計允許每個節點在本地維護最新模型權重，
        並支援多任務並行運行。在多任務環境下，
        排程調度器（Scheduler）可以根據節點的實際資源狀態、
        模型權重的新舊程度以及任務的優先級進行動態調度，
        使得訓練過程更加靈活且具彈性。
        每個 Worker 亦可對自身的 CPU / GPU 使用率、
        記憶體消耗與任務進度進行即時監控，
        並將監控資訊回報給 Scheduler，
        提供系統做出自適應調整的依據。
        透過這種設計，資源節點不僅能在運算效能上發揮最大效益，
        也能在系統穩定性與容錯能力上提供可靠保障。

        在任務分配方面，Scheduler 會綜合考量
        $W_"cpu"$ 和 $W_"gpu"$ 的可用資源、
        節點資料本地性以及保留的最新模型權重，
        並依據演算法選擇最適合的 Trial。
        簡單而言，演算法會：
        取出所有待執行的 Trial，
        並找出 最小世代 ($G_italic(bold("min"))$) 的 Trial 集合。
        在這些 Trial 中，
        優先選擇已保留最新模型權重且位於目標 Worker 的 Trial；
        若無符合條件者，則選擇最先加入的 Trial 作為備選。
        為選定 Trial 設定下一訓練階段，
        並將其標記為可在 GPU 或 CPU Worker 上執行。
        透過這種策略，Scheduler 能夠確保模型訓練直接沿用現有權重，
        減少網路 I/O 與跨節點資料搬移成本，
        提高 GPU 和 CPU 的利用率。
        每個 Worker 在運行期間持續監控自身的資源使用與任務進度，
        並即時回報給 Scheduler，
        使系統能根據資源動態變化進行自適應調整，
        確保負載均衡與高效運行。
        這種 Locality-Aware Scheduling 設計，
        不僅提升異質分散式環境中深度學習模型的訓練效率，
        也增強了系統穩定性與可擴展性，
        即使面對資源有限或變化頻繁的情況仍能保持高效運行。

        #[
            #set math.equation(numbering: none)
            #figure(
                kind: "algorithm",
                pseudocode-list(
                    booktabs: true,
                    numbered-title:
                    [Select a Trial with Latest Model Weights for Worker],
                )[
                    - *Input:* Worker $w_i$
                    - *Output:* Selected trial $t$
                    + Let $cal("T")$ be the set of all pending trials
                    + Find the minimal generation value:
                    - $ G_min = min {G_t | t in cal("T")} $
                    + Collect all trials with this minimal generation:
                    - $ T = { t in cal("T") | G_t = G_min } $
                    + From these trials,
                        select one that has stored model weights from $w_i$
                    + *if* no such trial exists *then*
                      + Select the first trial from $T$ as a fallback
                    + *end*
                    + *return* $t$
                ],
            )
        ]

        第二小節 Worker 進行訓練任務時會執行多個 generation
        （記為 $G^(W_"cpu")_i$ 或 $G^(W_"gpu")_i$），
        以減少模型反覆載入的次數並提升訓練效率。
        相較於上一年度的研究系統設計中，
        每次任務固定只完成一個 generation ($G_t$) 的做法，
        新的多 generation 架構能顯著降低系統在頻繁初始化模型與重載資料時的時間開銷。
        在此設計下，
        每個 Worker 能夠保留最新的模型權重與訓練狀態，
        使得後續的 $G_t$ 可以直接在現有權重基礎上持續更新，
        而無需重新載入模型或重新初始化訓練環境。
        這不僅縮短了每輪任務啟動所需的準備時間，
        也減少了跨節點的資料傳輸次數，
        有效提升整體系統的運算效率與穩定性。
        在資源管理層面，
        Scheduler 會根據節點的資源狀態與資料本地性進行動態任務分配，
        並優先選擇已保留最新模型權重的 Worker 執行 $G_t$，
        以充分利用現有模型狀態並避免不必要的模型同步開銷。
        這樣的 Locality-Aware Scheduling
        機制確保模型能在最接近資料來源的節點上持續訓練，
        降低網路延遲與 I/O 負擔，
        同時提升 GPU 與 CPU 的整體利用率。
        此外，每個 Worker 在多 generation 訓練過程中會持續監控
        CPU/GPU 使用率、
        記憶體占用及訓練進度，
        並即時回報給 Scheduler。
        透過這些動態監控資訊，
        系統能根據實際運行狀況調整資源分配與負載平衡，
        確保不同節點之間的工作效率保持最佳狀態。
        最終，透過多 generation 的訓練策略，
        整個分散式系統在異質環境下不僅展現出更高的運算吞吐量與穩定性，
        也成功減少了模型重載與初始化成本，
        使訓練過程更加連續、高效且具延展性。

        #figure(
            caption: [Worker 執行多 generation 的訓練策略],
            image("../assets/multi-generation1.png", width: 100%)
        )

        === Worker 與 Server 之間在資料交換時僅傳遞必要資訊，而模型權重則僅於任務完成後才回傳至 Server
        這樣的設計降低了網路傳輸負擔與頻繁同步造成的延遲，
        使整體訓練過程更加高效穩定。
        透過 Ray Actor 架構，
        每個 Worker ($W_"cpu"$ / $W_"gpu"}$) 能夠在本地端持續保留最新的模型權重、
        訓練狀態與超參數設定，
        並在完成多個 generation（$G^(W)_i$）的訓練階段後，
        才將更新後的權重上傳至 Server 進行整合、
        評估或進一步的選擇與突變操作。
        此架構的核心精神在於「將計算盡可能留在本地端」，
        有效降低資料頻繁來回傳輸的成本，
        並充分發揮各節點的運算效能。
        同時，Scheduler 會根據各 Worker 的訓練進度、
        計算資源使用率與當前系統負載，
        動態地調整任務分配策略，
        使整體系統能維持在資源最優化的運作狀態。
        藉由降低模型權重交換頻率，
        整個分散式訓練流程在維持模型精度與穩定性的同時，
        顯著提升了通訊效率與計算吞吐量。
        透過在本地端保留權重與歷史訓練紀錄，
        系統能更快地從中斷點恢復，
        並在後續任務中延續最佳化結果。
        整體而言，
        這種設計在效能、穩定性與可擴展性之間取得良好平衡，
        為異質環境下的大規模分散式訓練提供了高效率的運作基礎。

    == 預估 Trial 工作量的模型
    在異質性環境中執行超參數優化任務時，
    不同的超參數組合、模型結構以及執行節點特性，
    都會對訓練時間產生顯著影響。
    這種差異性使得相同的 Trial 在不同節點上執行時，
    可能出現數倍的時間差異，
    進而增加整體超參數搜尋的成本與不確定性。

    因此，如何準確預估各 Trial 的工作量（即其預期執行時間或資源消耗），
    成為設計高效排程演算法的關鍵。
    若能在排程前就估計各 Trial 在不同節點上的執行開銷，
    排程策略便能根據預測結果動態分配資源，
    在節點利用率、
    任務等待時間與*Trial 陳舊度（staleness）*之間取得更佳平衡，
    提升整體搜尋效率。

    傳統的排程方法多假設工作負載在各節點之間相似，
    或僅根據歷史平均時間進行分配，
    無法反映模型結構與硬體特性的複雜交互影響。
    為了解決此問題，
    本研究建立了一個基於多維特徵的 Trial 工作量預測模型，
    透過分析 Trial 的超參數、模型規模與硬體性能指標，
    預測其在異質節點上的執行時間，
    作為後續自適應排程與試驗分配策略的基礎。

        === 收集訓練資料
        本研究在叢集電腦系統上進行實驗，
        表一列出了叢集中各台電腦的硬體配置資訊。
        在超參數優化過程中，我們收集了每個 Trial 的相關資料，
        包括超參數設定與模型結構資訊，
        並同步記錄執行該 Trial 的工作節點硬體特徵。
        這些資料構成了後續工作量預測模型的輸入特徵，
        用於分析 Trial 在不同節點上的計算負載。

        #figure(
            table(
                columns: 3,
                table.header([CPU], [Memory], [NVIDIA GPU]),
                [Intel Xeon W-2235], [125 GiB], [NVIDIA GeForce RTX 3090],
                [Intel Xeon W-2235], [125 GiB], [NVIDIA GeForce GTX TITAN X],
                [Intel Core i5-6400], [15.5 GiB], [NVIDIA GeForce GTX 960],
                [Intel Celeron G6900], [15.7 GiB], [NVIDIA T400],
                [Intel Core i5-6400], [7.8 GiB], [N/A],
            ),
            caption: [叢集設定],
        ) <hardware-table-3-1>

        為確保資料的準確性與一致性，
        系統在每次 Trial 執行期間自動化地記錄訓練過程資訊，
        包括模型初始化設定、訓練過程中量測到的計算時間、
        以及所屬節點的硬體資源使用情況。
        所有資料皆以統一格式儲存，方便後續特徵處理與模型訓練。

        - Trial 資訊包括：
            - 當前模型的準確率
            - 模型參數總數
            - 學習率（learning rate）
            - 動量（momentum）
            - 批次大小（batch size）
        - 硬體特徵涵蓋：
            - GPU：CUDA 核心數量、記憶體容量、最高與最低執行頻率。
            - CPU：核心數量、最高與最低執行頻率。
            - 主記憶體：系統可用記憶體容量。

        在資料清理階段，排除了記錄中包含空值或不完整欄位的 Trial，
        以確保輸入資料的一致性與完整性。
        接著，對所有數值型特徵進行單位統一處理，
        例如將 GPU 與 CPU 的頻率統一轉換為 GHz，
        記憶體容量統一以 GB 表示，
        以避免不同量測單位導致的偏差。

        此外，為降低各硬體類型在資料分布上的不平衡，
        本研究針對不同硬體配置（如 GPU 型號或 CPU 規格）進行樣本數調整，
        使各硬體組別的 Trial 數量相當，
        確保模型在訓練過程中能均衡學習不同節點特性的影響。

        在本研究中，Trial 的工作量以每次訓練迭代（batch）的執行時間，
        代表該 Trial 在特定節點上的實際計算負擔。
        最終整理後的資料集涵蓋多組超參數設定與多樣化硬體環境，
        作為後續建立與驗證工作量預測模型的重要基礎。

        === 超參數與架構分析
        為了降低模型的複雜度並提升預測效能，
        本研究在建立工作量預測模型前，
        先對各項超參數與模型結構特徵進行相關性分析，
        以排除與工作量關聯性較低的特徵。

        我們以 Trial 的工作量作為目標變數，
        計算各輸入特徵與工作量之間的皮爾森相關係數
        （Pearson correlation coefficient），
        並輔以熱力圖（correlation heatmap）
        進行可視化，以辨識特徵間的相關程度。

        #figure(
            image("../assets/matrix.png", width: 90%),
            caption: [特徵之間相關係數的熱力圖],
        ) <matrix>

        如@matrix 所示，
        batch size、模型參數總數以及 GPU 頻率上限等特徵
        與工作量（batch_time）之間存在中度至高度的相關性；
        這意味著模型規模或硬體運算能力越低，
        單次訓練批次的平均時間亦相對增加。
        相對地，部分超參數（如 momentum）與工作量的線性關聯較弱，
        顯示其主要影響模型收斂行為，而非即時運算負載。

        僅保留與工作量相關係數大於等於參數量與工作量的相關係數的特徵，
        作為後續模型訓練的輸入。
        此舉能有效減少不具貢獻的特徵維度，
        降低模型過擬合風險，
        並提升模型在不同節點與超參數組合下的泛化能力。

        === 模型架構及訓練
        在確立了資料集和輸入的特徵後，
        本研究設計了一個基於多層感知機（Muli-Layer Perceptron, MLP）
        的回歸模型，用於預測 Trial 的工作量（即單次迭代的執行時間）。
        該模型由若干隱藏層組成，並結合非線性激活函數與 Dropout 層，
        以對稱的結構組成，
        在總共 $N$ 個的隱藏層中，第 $i$ 層的維度如下公式@dim 所示
        ，其中 $italic("basedim")$ 是模型架構的其中一個超參數。
        能有效補捉超參數、模型結構與硬體特徵之間的複雜關係。

        $
            italic("dim")_i = cases(
                italic("basedim") times 2^i ", if" i < N/2,
                italic("basedim") times 2^(N - i),
            )
        $ <dim>

        模型的輸入張量包含了上一小節篩選留下的超參數、
        模型參數量和硬體特徵，總計 $10$ 維。
        輸出為一個純量，代表該 Trial 的預計執行時間（單位：秒）。

        為了提升最後模型的效果，本研究的訓練過程使用了以下的策略：
        + *資料分割*：將整理後的資料集分割為訓練集（$70%$）、
            驗證集（$10%$）和\ 測試集（$20%$）。
        + *早停策略*：若在驗證集的損失連續 $5$ 個 epochs 沒有下降，
            則提前終止訓練。
        + *優化器*：使用 Adam 優化演算法
            和 Cosine Annealing 演算法，動態調整訓練過程中的學習率。
        + *超參數優化*：使用 Optuna 套件提供的演算法，
            進行訓練的超參數優化。
