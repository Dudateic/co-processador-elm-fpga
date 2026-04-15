import numpy as np
import os

def hex_to_int16(hex_str):
    value = int(hex_str.strip(), 16)

    if value >= 0x8000:
        value -= 0x10000

    return value

def carregar_hex(arquivo):
    with open(arquivo, "r") as f:
        linhas = f.readlines()

    dados = [hex_to_int16(linha) for linha in linhas]
    return np.array(dados, dtype=np.int32)

# Sigmoide
def sigmoid(x):
    x_float = x / (1 << 12)
    y = 1.0 / (1.0 + np.exp(-x_float))

    return (y * (1 << 12)).astype(np.int32)

# Carregar pesos TXT
def carregar_pesos(pasta_pesos):
    W = carregar_hex(os.path.join(pasta_pesos, "W_in_q.hex"))
    b = carregar_hex(os.path.join(pasta_pesos, "b_q.hex"))
    beta = carregar_hex(os.path.join(pasta_pesos, "beta_q.hex"))

    hidden_size = b.shape[0]

    input_size = int(len(W) / hidden_size)
    output_size = int(len(beta) / hidden_size)

    W = W.reshape(hidden_size, input_size)
    beta = beta.reshape(hidden_size, output_size)

    return W, b, beta

def carregar_imagem(caminho):
    x = carregar_hex(caminho)

    if len(x) != 784:
        raise ValueError(f"Entrada com tamanho errado: {len(x)}")

    x = (x << 12) // 255

    return x

# Inferência ELM
def elm_inferencia(x, W, b, beta):

    # Primeira camada
    H = np.zeros(W.shape[0], dtype=np.int32)

    for i in range(W.shape[0]):
        acc = 0

        for j in range(W.shape[1]):
            acc += (W[i, j] * x[j]) >> 12

        acc += b[i]

        H[i] = acc

    # Sigmoid
    H = sigmoid(H)

    # Segunda camada
    y = np.zeros(beta.shape[1], dtype=np.int32)

    for k in range(beta.shape[1]):
        acc = 0

        for i in range(beta.shape[0]):
            acc += (H[i] * beta[i, k]) >> 12

        y[k] = acc

    return y

# Inferência
def rodar_inferencia(pasta_imagens, pasta_pesos, arquivo_labels):
    W, b, beta = carregar_pesos(pasta_pesos)
    labels = np.loadtxt(arquivo_labels, dtype=int)

    arquivos = sorted([f for f in os.listdir(pasta_imagens) if f.endswith(".hex")])

    acertos = 0
    total = 0

    print("W:", W.shape)
    print("beta:", beta.shape)

    for i, arquivo in enumerate(arquivos):

        caminho = os.path.join(pasta_imagens, arquivo)

        x = carregar_imagem(caminho)
        y = elm_inferencia(x, W, b, beta)

        pred = np.argmax(y)
        label = labels[i]

        if pred == label:
            acertos += 1

        total += 1

        print(f"{arquivo} -> Pred: {pred} | Label: {label}")

    acuracia = acertos / total

    print("\n====================")
    print(f"Acurácia: {acuracia*100:.2f}%")
    print(f"Acertos: {acertos}/{total}")

if __name__ == "__main__":
    pasta_imagens = "imgs"
    pasta_pesos = "pesosvies"
    labels = "labels.txt"

    rodar_inferencia(pasta_imagens, pasta_pesos, labels)
