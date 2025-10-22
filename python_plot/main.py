from pathlib import Path

import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import pandas as pd
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score


def plot(df: pd.DataFrame) -> None:
    output_dir: Path = Path(__file__).parent.parent / "assets"

    # 真實值與預測值
    y_true = df["origin"].values
    y_pred = df["predict"].values
    # -----------------------------
    # 1. 散點圖：預測值 vs 真實值
    # -----------------------------
    plt.figure(figsize=(6, 6))
    plt.scatter(y_true, y_pred, alpha=0.6)
    plt.plot(
        [min(y_true), max(y_true)],
        [min(y_true), max(y_true)],
        "r--",
        label="y=x",
    )
    plt.xlabel("True Time(s)")
    plt.ylabel("Predicted Time(s)")
    plt.title("Predicted vs True Execution Time")
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(output_dir / "predicted_vs_true.png")

    # -----------------------------
    # 3. 小提琴圖：origin / predict / diff 分布
    # -----------------------------
    plt.figure(figsize=(6, 4))
    violin_data = pd.DataFrame(
        {
            "Ground Truth": y_true,
            "Predicted Value": y_pred,
        }
    )

    sns.violinplot(data=violin_data, inner="box", palette="Set2", bw=0.3)
    plt.ylabel("Execution Time(s)")
    plt.grid(axis="y", linestyle="--", alpha=0.6)
    plt.tight_layout()
    plt.savefig(output_dir / "violin_plot.png")
    plt.close()


def main() -> None:
    file: Path = Path("results") / "results.csv"
    # 讀取 CSV
    df = pd.read_csv(file)

    # 真實值與預測值
    y_true = df["origin"].values
    y_pred = df["predict"].values
    # 差值
    diff = df["diff"].values

    # 基本統計
    bias = np.mean(diff)
    print(f"最小值 origin {min(y_true)} predict {min(y_pred)}")
    std_diff = np.std(diff)
    print("Bias (平均偏差):", bias)
    print("誤差標準差 (Std of diff):", std_diff)

    # MAE
    mae = mean_absolute_error(y_true, y_pred)
    print("MAE:", mae)

    # MSE
    mse = mean_squared_error(y_true, y_pred)
    print("MSE:", mse)

    # RMSE
    rmse = np.sqrt(mse)
    print("RMSE:", rmse)

    # R²
    r2 = r2_score(y_true, y_pred)
    print("R²:", r2)

    # 皮爾森相關係數
    pearson_r = np.corrcoef(y_true, y_pred)[0, 1]
    print("Pearson r:", pearson_r)

    plot(df)


if __name__ == "__main__":
    main()
