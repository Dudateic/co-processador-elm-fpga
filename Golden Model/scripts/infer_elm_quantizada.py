#!/usr/bin/env python3


"""
Receive a MNIST image (PNG 28x28 pixels) and perform inference using a trained
Extreme Learning Machine (ELM) model. The output is an integer in the range
[0, 9], corresponding to the predicted digit.

Original script:
    Angelo Duarte, Copyright (C) Feb. 2026


The implementation of this script (infer_elm_quantizada.py), as well as
train_elm_quantizada.py, was originally developed by Angelo Duarte.

Modifications:
    Maria Eduarda
    - Adaptation to the project directory structure.
    - Integration with the FPGA validation workflow.
    - Code organization and documentation improvements.

Usage:
    python3 infer_elm_quantizada.py \
        --model models/model_elm_fp32.npz \
        --image path/to/image.png
"""


import argparse
from pathlib import Path
import numpy as np
from PIL import Image

def activation(x, kind="tanh"):
    if kind == "tanh":
        return np.tanh(x)
    elif kind == "relu":
        return np.maximum(x, 0.0)
    elif kind == "sigmoid":
        return 1.0 / (1.0 + np.exp(-x))
    else:
        raise ValueError("activation deve ser: tanh | relu | sigmoid")

def load_image_as_vector(img_path: Path, image_size=(28, 28)):
    img = Image.open(img_path).convert("L")
    if img.size != image_size:
        img = img.resize(image_size, Image.Resampling.BILINEAR)

    x_u8 = np.array(img, dtype=np.float32)   # 0..255
    x = (x_u8 / 255.0).reshape(-1)           # (784,)
    return x

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", type=str, required=True, help="Caminho para o .npz (fp32 ou quantizado)")
    ap.add_argument("--image", type=str, required=True, help="Caminho para PNG 28x28")
    args = ap.parse_args()

    model_path = Path(args.model)
    img_path = Path(args.image)

    m = np.load(model_path, allow_pickle=True)
    act = str(m["activation"])
    
    # Verifica se o modelo carregado é o quantizado
    if "W_in_q" in m.files:
        print("[INFO] Modelo quantizado detectado. Carregando e simulando em Q4.12...")
        # Carrega os inteiros e o fator fracionário
        q_frac = int(m["q_frac"])
        scale = 2 ** q_frac
        
        # Converte de volta para float apenas para simular a precisão da matemática em Python
        W_in = m["W_in_q"].astype(np.float32) / scale
        b    = m["b_q"].astype(np.float32) / scale
        beta = m["beta_q"].astype(np.float32) / scale
    else:
        print("[INFO] Modelo Float32 detectado.")
        # Carrega o modelo original normalmente
        W_in = m["W_in"].astype(np.float32)     # (H, D)
        b    = m["b"].astype(np.float32)        # (H,)
        beta = m["beta"].astype(np.float32)     # (H, C)

    x = load_image_as_vector(img_path, image_size=(28, 28))  # (D,)
    
    # Forward (Inferência)
    z = W_in @ x + b                 # (H,)
    h = activation(z, kind=act)      # (H,)
    y = h @ beta                     # (C,)
    pred = int(np.argmax(y))

    print(f"Dígito previsto: {pred}")
    
if __name__ == "__main__":
    main()