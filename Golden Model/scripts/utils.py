import os
import numpy as np
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix

"""
Utility functions for the Golden Model evaluation.

This module provides functions for:
    - Confusion matrix generation
    - Accuracy and error analysis
    - FPGA versus Golden Model comparison
    - Performance visualization
    - Plot generation
    
Author:
    Maria Eduarda Teixeira Costa

Copyright (C) 2026 Maria Eduarda Teixeira Costa

"""

def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def plot_confusion_golden(y_true, y_pred, save_path=None, normalize=True):

    cm = confusion_matrix(y_true, y_pred)

    plt.figure(figsize=(7, 6))
    sns.heatmap(
        cm,
        annot=True,
        fmt="d",
        cmap="Blues",
        xticklabels=range(10),
        yticklabels=range(10)
    )

    plt.title("Golden Model - Matriz de Confusão")
    plt.xlabel("Predito")
    plt.ylabel("Real")
    plt.tight_layout()

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=250)

    plt.close()

def plot_confusion_fpga(csv_path, save_path=None):

    df = pd.read_csv(csv_path)

    cm = df.iloc[:, 1:].values
    
    plt.figure(figsize=(7, 6))
    sns.heatmap(
        cm,
        annot=True,
        fmt="d",
        cmap="Greens",
        xticklabels=range(10),
        yticklabels=range(10)
    )

    plt.title("FPGA - Matriz de Confusão")
    plt.xlabel("Predito")
    plt.ylabel("Real")
    plt.tight_layout()

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=250)

    plt.close()



def compare_confusion(golden_true, golden_pred, fpga_csv, save_path=None):

    cm_gold = confusion_matrix(golden_true, golden_pred)

    df_fpga = pd.read_csv(fpga_csv)
    cm_fpga = df_fpga.iloc[:, 1:].values

    fig, ax = plt.subplots(1, 2, figsize=(14, 6))

    sns.heatmap(cm_gold, annot=True, fmt="d", cmap="Blues", ax=ax[0])
    ax[0].set_title("Golden Model")

    sns.heatmap(cm_fpga, annot=True, fmt="d", cmap="Greens", ax=ax[1])
    ax[1].set_title("FPGA")

    plt.tight_layout()

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=300)

    plt.close()


def plot_error(y_true, y_pred, save_path=None):

    y_true = np.array(y_true)
    y_pred = np.array(y_pred)

    acc = int(np.sum(y_true == y_pred))
    err = int(np.sum(y_true != y_pred))

    total = acc + err
    acc_pct = acc / total * 100
    err_pct = err / total * 100

    plt.figure(figsize=(6, 4))

    bars = plt.bar(
        ["Acertos", "Erros"],
        [acc, err],
        color=["green", "red"]
    )

    plt.title("Golden Model - Acertos vs Erros")
    plt.ylabel("Quantidade")
    plt.grid(axis="y", alpha=0.3)

    for b, val, pct in zip(bars, [acc, err], [acc_pct, err_pct]):
        plt.text(
            b.get_x() + b.get_width()/2,
            b.get_height(),
            f"{int(b.get_height())}",
            ha="center"
        )

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=250)

    plt.close()

def plot_golden_metrics(train_acc, test_acc, save_path=None):

    plt.figure(figsize=(6,4))

    bars = plt.bar(
        ["Train", "Test"],
        [train_acc, test_acc],
    )

    plt.title("Golden Model - Accuracy")
    plt.ylabel("Accuracy (%)")
    plt.ylim(0,100)
    plt.grid(axis="y", alpha=0.3)

    for b in bars:
        plt.text(
            b.get_x()+b.get_width()/2,
            b.get_height()+0.3,
            f"{b.get_height():.2f}%",
            ha="center"
        )

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path,dpi=300,bbox_inches="tight")

    plt.close()

def plot_fpga_errors(csv_path, save_path=None):

    df = pd.read_csv(csv_path)

    correct = (df["Correto"] == "SIM").sum()
    wrong = (df["Correto"] != "SIM").sum()

    plt.figure(figsize=(6,4))
    bars = plt.bar(["Acertos", "Erros"], [correct, wrong],
                   color=["green", "red"])

    plt.title("FPGA - Acertos vs Erros")
    plt.grid(axis="y", alpha=0.3)

    for b in bars:
        plt.text(
            b.get_x() + b.get_width()/2,
            b.get_height(),
            f"{int(b.get_height())}",
            ha="center"
        )

    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        plt.savefig(save_path, dpi=300)

    plt.close()

def plot_comparison_metrics(golden_acc, fpga_acc, save_path=None):

    diff = abs(golden_acc-fpga_acc)

    labels = [
        "Golden\nAccuracy",
        "FPGA\nAccuracy",
        "Difference"
    ]

    values = [
        golden_acc,
        fpga_acc,
        diff
    ]

    plt.figure(figsize=(7,4))

    bars = plt.bar(labels, values)

    plt.title("Golden Model × FPGA")
    plt.ylabel("Value (%)")
    plt.grid(axis="y", alpha=0.3)

    for b in bars:
        plt.text(
            b.get_x()+b.get_width()/2,
            b.get_height()+0.3,
            f"{b.get_height():.2f}",
            ha="center"
        )

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path,dpi=300,bbox_inches="tight")

    plt.close()

def plot_latency(latencies, save_path=None):

    lat = np.array(latencies)

    plt.figure(figsize=(8, 4))
    plt.plot(lat, marker="o", linewidth=1)
    plt.axhline(lat.mean(), color="red", linestyle="--", label="Média")

    plt.title("Latência de Inferência (Golden Model)")
    plt.xlabel("Amostras")
    plt.ylabel("Tempo")
    plt.legend()
    plt.grid()

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=250)

    plt.close()

def load_fpga_metrics(folder):

    met = pd.read_csv(os.path.join(folder, "test_1000_metricas.csv"))
    dig = pd.read_csv(os.path.join(folder, "test_1000_por_digito.csv"))

    return met, dig

def plot_fpga_digit_accuracy(csv_path, save_path):

    os.makedirs(os.path.dirname(save_path), exist_ok=True)

    df = pd.read_csv(csv_path)

    plt.figure(figsize=(10, 5))

    bars = plt.bar(df["Digito"], df["Acuracia(%)"], color="steelblue")

    plt.title("FPGA Accuracy por Dígito")
    plt.xlabel("Dígito")
    plt.ylabel("Accuracy (%)")
    plt.ylim(0, 100)
    plt.grid(axis="y", alpha=0.3)

    for b in bars:
        plt.text(
            b.get_x() + b.get_width()/2,
            b.get_height(),
            f"{b.get_height():.1f}%",
            ha="center",
            va="bottom",
            fontsize=9
        )

    plt.tight_layout()
    plt.savefig(save_path, dpi=300)
    plt.close()



def plot_fpga_vs_golden(fpga_acc, golden_acc, save_path=None):

    plt.figure(figsize=(6,4))

    plt.bar(["FPGA", "Golden Model"], [fpga_acc, golden_acc],
            color=["orange", "blue"])

    plt.title("FPGA vs Golden Model - Accuracy")
    plt.ylabel("Accuracy (%)")
    plt.grid(axis="y", alpha=0.3)

    if save_path:
        ensure_dir(os.path.dirname(save_path))
        plt.savefig(save_path, dpi=250)

    plt.close()