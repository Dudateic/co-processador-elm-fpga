#!/usr/bin/env python3
import argparse
import os
import time
import numpy as np

from pathlib import Path
from PIL import Image

"""
Original implementation:
    Angelo Duarte

Copyright (C) 2026 Angelo Duarte
"""

def list_images(root: Path):
    exts = {".png", ".jpg", ".jpeg", ".bmp"}
    files = []
    for p in root.rglob("*"):
        if p.is_file() and p.suffix.lower() in exts:
            files.append(p)
    return sorted(files)

def load_dataset_split(split_dir: Path, image_size=(28, 28), limit_per_class=None):
    """
    split_dir/
      0/
      1/
      ...
      9/
    """
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

            arr = np.array(img, dtype=np.float32)  # 0..255
            arr = arr.reshape(-1)                  # D=784
            X_list.append(arr)
            y_list.append(digit)

    X = np.stack(X_list, axis=0)  # (N, D)
    y = np.array(y_list, dtype=np.int64)  # (N,)
    return X, y

def one_hot(y, num_classes=10):
    Y = np.zeros((y.shape[0], num_classes), dtype=np.float32)
    Y[np.arange(y.shape[0]), y] = 1.0
    return Y

def activation(x, kind="tanh"):
    if kind == "tanh":
        return np.tanh(x)
    elif kind == "relu":
        return np.maximum(x, 0.0)
    elif kind == "sigmoid":
        return 1.0 / (1.0 + np.exp(-x))
    else:
        raise ValueError("activation deve ser: tanh | relu | sigmoid")

def quantize_symmetric(x, frac_bits):
    """
    Quantização simétrica em int16 por padrão (depende do range).
    Retorna (x_q_int32, scale).
    x ≈ x_q / 2^frac_bits
    """
    scale = 2 ** frac_bits
    xq = np.round(x * scale)

    # clipagem para garantir que não havera overflow
    xq_clipped = np.clip(xq,-32768, 32767)
    return xq_clipped.astype(np.int16), scale

def save_bins(out_dir: Path, W_in_q, b_q, beta_q):
    # little-endian int16 ("<i2") para o formato Q4.12
    (out_dir / "W_in_q_i16.bin").write_bytes(W_in_q.astype("<i2").tobytes())
    (out_dir / "b_q_i16.bin").write_bytes(b_q.astype("<i2").tobytes())
    (out_dir / "beta_q_i16.bin").write_bytes(beta_q.astype("<i2").tobytes())


def main(seed):
    ap = argparse.ArgumentParser()
    ap.add_argument("--data_root", type=str, required=True, help="Pasta com train/ e test/")
    ap.add_argument("--hidden", type=int, default=128, help="Número de neurônios ocultos H")
    ap.add_argument("--lambda_ridge", type=float, default=1e-3, help="Regularização ridge (λ)")
    ap.add_argument("--activation", type=str, default="tanh", choices=["tanh", "relu", "sigmoid"])
    ap.add_argument("--seed", type=int, default=123)
    ap.add_argument("--limit_per_class", type=int, default=None, help="Limitar imagens por classe (debug)")
    ap.add_argument("--q_frac", type=int, default=12, help="Bits fracionários para quantização (Qm.q_frac)")
    ap.add_argument("--out_dir", type=str, default="elm_out")
    ap.add_argument("--dump_bins", action="store_true")
    args = ap.parse_args()

    data_root = Path(args.data_root)
    train_dir = data_root / "train"
    test_dir  = data_root / "test"
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    # 1) Carrega dados
    Xtr_u8, ytr = load_dataset_split(train_dir, image_size=(28, 28), limit_per_class=args.limit_per_class)
    Xte_u8, yte = load_dataset_split(test_dir,  image_size=(28, 28), limit_per_class=args.limit_per_class)

    # Normalização simples: [0,1]
    Xtr = (Xtr_u8 / 255.0).astype(np.float32)
    Xte = (Xte_u8 / 255.0).astype(np.float32)

    N, D = Xtr.shape
    H = args.hidden
    C = 10

    # 2) Inicializa pesos de entrada fixos
    rng = np.random.default_rng(seed)
    # Normal(0,1) é ok; também pode usar Uniform(-1,1)
    W_in = rng.standard_normal((H, D), dtype=np.float32)
    b    = rng.standard_normal((H,), dtype=np.float32)

    # 3) Calcula camada oculta para treino
    # Htr = act(W_in X + b)
    # Nota: (N,D) -> (N,H) via X @ W_in.T
    Ztr = Xtr @ W_in.T + b
    Htr = activation(Ztr, kind=args.activation).astype(np.float32)

    # 4) Resolve β por ridge regression fechada:
    # β = (H^T H + λI)^(-1) H^T Y
    Ytr = one_hot(ytr, num_classes=C)
    lam = args.lambda_ridge

    HtH = Htr.T @ Htr  # (H,H)
    reg = lam * np.eye(H, dtype=np.float32)
    A = HtH + reg
    B = Htr.T @ Ytr    # (H,C)
    beta = np.linalg.solve(A, B).astype(np.float32)  # (H,C)

    # 5) Avalia
    def predict(X):
        start = time.time()

        Z = X @ W_in.T + b
        Hh = activation(Z, kind=args.activation)
        Y = Hh @ beta
        y_pred = np.argmax(Y, axis=1)

        end = time.time()
        latency = end - start

        return y_pred, latency

    yhat_tr, _  = predict(Xtr)
    yhat_te, _  = predict(Xte)
    acc_tr = (yhat_tr == ytr).mean()
    acc_te = (yhat_te == yte).mean()

    print(f"[ELM] D={D} H={H} C={C} act={args.activation} lambda={lam} seed ={seed}")
    print(f"[ELM] acc_train={acc_tr*100:.2f}% acc_test={acc_te*100:.2f}%")

    # 6) Salva float32 (referência)
    np.savez(out_dir / "model_elm_fp32.npz",
             W_in=W_in, b=b, beta=beta,
             activation=args.activation,
             lambda_ridge=np.float32(lam),
             seed=np.int32(args.seed),
             input_norm=np.bytes_("x/255.0"))

    # 7) Quantiza para FPGA (simétrica, mesma Q para tudo por simplicidade)
    q = args.q_frac
    W_in_q, sW = quantize_symmetric(W_in, q)   # int16
    b_q,    sb = quantize_symmetric(b, q)
    beta_q, sB = quantize_symmetric(beta, q)

    np.savez(out_dir / "model_elm_q.npz",
            W_in_q=W_in_q, b_q=b_q, beta_q=beta_q,
            q_frac=np.int32(q),
            activation=args.activation,
            note="x_real ~= x_q / 2^q_frac; int16; little-endian dumps opcionais")

    if args.dump_bins:
        save_bins(out_dir, W_in_q, b_q, beta_q)

    # 8) Salva um arquivo texto com metadados úteis para o enunciado/FPGA
    meta = out_dir / "meta.txt"
    meta.write_text(
        f"D={D}\nH={H}\nC={C}\nactivation={args.activation}\n"
        f"lambda_ridge={lam}\nseed={args.seed}\nq_frac={q}\n"
        f"norm=x/255.0\n"
    )
    print(f"[OK] Modelos salvos em: {out_dir.resolve()}")

if __name__ == "__main__":
    main(82)