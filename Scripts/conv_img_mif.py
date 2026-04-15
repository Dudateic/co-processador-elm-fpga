import os
from PIL import Image
import numpy as np

def imagem_para_mif(caminho_imagem, caminho_saida):
    img = Image.open(caminho_imagem).convert('L')
    img = img.resize((28, 28))

    pixels = np.array(img)

    # Lembrar: caso precise adequar o padrão das imagens
    # onde se for branco 255 e se for fundo 0 -> é so descomentar a linha abaixo
    # pixels = 255 - pixels

    pixels_flat = pixels.flatten()

    with open(caminho_saida, 'w') as f:
        f.write("DEPTH = 784;\n")
        f.write("WIDTH = 8;\n")
        f.write("ADDRESS_RADIX = DEC;\n")
        f.write("DATA_RADIX = HEX;\n")
        f.write("CONTENT BEGIN\n")

        for i, val in enumerate(pixels_flat):
            f.write(f"\t{i} : {val:02X};\n")

        f.write("END;\n")


def converter_pasta(pasta_entrada, pasta_saida):
    os.makedirs(pasta_saida, exist_ok=True)

    for arquivo in os.listdir(pasta_entrada):
        if arquivo.lower().endswith(('.png')):
            
            caminho_img = os.path.join(pasta_entrada, arquivo)
            
            nome_base = os.path.splitext(arquivo)[0]
            caminho_mif = os.path.join(pasta_saida, nome_base + ".mif")

            imagem_para_mif(caminho_img, caminho_mif)

            print(f"Convertido: {arquivo} → {nome_base}.mif")


converter_pasta("/home/duda/Documents/Code/convert/test/9", "test_mif/9")