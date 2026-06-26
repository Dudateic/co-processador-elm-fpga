#!/usr/bin/env python3

"""
Evaluates the Golden Model and compares its results with the FPGA implementation.

This script:
    - Loads the trained ELM model.
    - Executes inference on the MNIST test dataset.
    - Computes classification metrics.
    - Compares the Golden Model against the FPGA implementation.
    - Generates plots used for experimental validation.

Author:
    Maria Eduarda Teixeira Costa

Copyright (C) 2026 Maria Eduarda Teixeira Costa
"""

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd
from PIL import Image

from utils import (
    plot_confusion_golden,
    plot_confusion_fpga,
    compare_confusion,
    plot_error,
    plot_fpga_errors,
    load_fpga_metrics,
    plot_fpga_digit_accuracy,
    plot_fpga_vs_golden,
    plot_golden_metrics,
    plot_comparison_metrics,
)


def list_images(root: Path):
    exts = {".png", ".jpg", ".jpeg", ".bmp"}
    files = []

    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() in exts:
            files.append(p)

    return sorted(files)


def load_dataset_split(split_dir: Path, image_size=(28, 28), limit_per_class=None):
    X_list = []
    y_list = []

    for digit in range(10):
        class_dir = split_dir / str(digit)

        if not class_dir.exists():
            raise FileNotFoundError(f"Pasta não encontrada: {class_dir}")

        imgs = list_images(class_dir)

        if limit_per_class is not None:
            imgs = imgs[:limit_per_class]

        for img_path in imgs:
            img = Image.open(img_path).convert("L")

            if img.size != image_size:
                img = img.resize(image_size, Image.Resampling.BILINEAR)

            arr = np.array(img, dtype=np.float32)
            arr = arr.reshape(-1)

            X_list.append(arr)
            y_list.append(digit)

    X = np.stack(X_list, axis=0)
    y = np.array(y_list, dtype=np.int64)

    return X, y


def activation(x, kind="tanh"):
    if kind == "tanh":
        return np.tanh(x)

    if kind == "relu":
        return np.maximum(x, 0.0)

    if kind == "sigmoid":
        return 1.0 / (1.0 + np.exp(-x))

    raise ValueError("activation deve ser: tanh | relu | sigmoid")


def load_model(model_path: Path):
    model = np.load(model_path, allow_pickle=True)

    act = str(model["activation"])

    if "W_in_q" in model.files:
        print("[INFO] Modelo quantizado detectado.")

        q_frac = int(model["q_frac"])
        scale = 2 ** q_frac

        W_in = model["W_in_q"].astype(np.float32) / scale
        b = model["b_q"].astype(np.float32) / scale
        beta = model["beta_q"].astype(np.float32) / scale

    else:
        print("[INFO] Modelo Float32 detectado.")

        W_in = model["W_in"].astype(np.float32)
        b = model["b"].astype(np.float32)
        beta = model["beta"].astype(np.float32)

    return W_in, b, beta, act


def predict(X, W_in, b, beta, act):
    Z = X @ W_in.T + b
    H = activation(Z, kind=act)
    Y = H @ beta

    y_pred = np.argmax(Y, axis=1)

    return y_pred


def main():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--data_root",
        type=str,
        required=True,
        help="Pasta contendo train/ e test/",
    )

    parser.add_argument(
        "--model",
        type=str,
        default=None,
        help="Caminho do modelo .npz. Se não passar, usa models/model_elm_fp32.npz",
    )

    parser.add_argument(
        "--fpga_output",
        type=str,
        default=None,
        help="Pasta output do Driver da FPGA",
    )

    parser.add_argument(
        "--limit_per_class",
        type=int,
        default=None,
        help="Limita imagens por classe para debug",
    )

    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent

    models_dir = project_root / "models"
    comparison_dir = project_root / "comparison"

    metrics_dir = comparison_dir / "metrics"
    confusion_dir = comparison_dir / "confusion_matrix"

    metrics_dir.mkdir(parents=True, exist_ok=True)
    confusion_dir.mkdir(parents=True, exist_ok=True)

    data_root = Path(args.data_root).resolve()
    train_dir = data_root / "train"
    test_dir = data_root / "test"

    if args.model is None:
        model_path = models_dir / "model_elm_fp32.npz"
    else:
        model_path = Path(args.model).resolve()

    if not model_path.exists():
        raise FileNotFoundError(f"Modelo não encontrado: {model_path}")

    print(f"[INFO] Carregando modelo: {model_path}")

    W_in, b, beta, act = load_model(model_path)

    print("[INFO] Carregando dataset...")

    Xtr_u8, ytr = load_dataset_split(
        train_dir,
        image_size=(28, 28),
        limit_per_class=args.limit_per_class,
    )

    Xte_u8, yte = load_dataset_split(
        test_dir,
        image_size=(28, 28),
        limit_per_class=args.limit_per_class,
    )

    Xtr = (Xtr_u8 / 255.0).astype(np.float32)
    Xte = (Xte_u8 / 255.0).astype(np.float32)

    print("[INFO] Executando inferência do Golden Model...")

    yhat_tr = predict(Xtr, W_in, b, beta, act)
    yhat_te = predict(Xte, W_in, b, beta, act)

    acc_tr = np.mean(yhat_tr == ytr)
    acc_te = np.mean(yhat_te == yte)

    print(f"Train acc: {acc_tr:.4f}")
    print(f"Test acc:  {acc_te:.4f}")

    plot_confusion_golden(
        yte,
        yhat_te,
        save_path=str(confusion_dir / "golden_confusion.png"),
    )

    plot_error(
        yte,
        yhat_te,
        save_path=str(metrics_dir / "golden_error.png"),
    )

    plot_golden_metrics(
        acc_tr*100,
        acc_te*100,
        save_path=metrics_dir/"golden_metrics.png"
    )

    print(f"[OK] Métricas do Golden salvas")

    if args.fpga_output is None:
        print("[AVISO] --fpga_output não foi informado.")
        print("[OK] Gráficos do Golden Model gerados.")
        return

    fpga_folder = Path(args.fpga_output).resolve()

    if not fpga_folder.exists():
        raise FileNotFoundError(f"Pasta da FPGA não encontrada: {fpga_folder}")

    print(f"[INFO] Carregando resultados da FPGA: {fpga_folder}")

    required_files = [
        "test_1000_metricas.csv",
        "test_1000_por_digito.csv",
        "test_1000_confusao.csv",
        "test_1000_detalhes.csv",
    ]

    for filename in required_files:
        file_path = fpga_folder / filename
        if not file_path.exists():
            raise FileNotFoundError(f"Arquivo da FPGA não encontrado: {file_path}")

    met, _ = load_fpga_metrics(str(fpga_folder))

    fpga_acc = float(
        met.loc[
            met["Metrica"] == "Acuracia Global (%)",
            "Valor",
        ].values[0]
    )

    plot_fpga_digit_accuracy(
        str(fpga_folder / "test_1000_por_digito.csv"),
        save_path=str(metrics_dir / "fpga_digit_accuracy.png"),
    )

    plot_confusion_fpga(
        str(fpga_folder / "test_1000_confusao.csv"),
        save_path=str(confusion_dir / "fpga_confusion.png"),
    )

    compare_confusion(
        yte,
        yhat_te,
        str(fpga_folder / "test_1000_confusao.csv"),
        save_path=str(confusion_dir / "comparison_confusion.png"),
    )

    plot_fpga_vs_golden(
        fpga_acc,
        acc_te * 100,
        save_path=str(metrics_dir / "fpga_vs_golden.png"),
    )

    plot_fpga_errors(
        str(fpga_folder / "test_1000_detalhes.csv"),
        save_path=str(metrics_dir / "fpga_errors.png"),
    )

    plot_comparison_metrics(
        acc_te*100,
        fpga_acc,
        save_path=metrics_dir/"comparison_metrics.png"
    )

    print("[OK] Avaliação concluída.")
    print(f"[OK] Métricas salvas em: {metrics_dir}")
    print(f"[OK] Matrizes salvas em: {confusion_dir}")


if __name__ == "__main__":
    main()