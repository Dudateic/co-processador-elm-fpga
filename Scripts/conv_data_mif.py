def txt_to_mif(input_file, output_file, width=16):
    with open(input_file, 'r') as f:
        data = [line.strip() for line in f if line.strip()]
    
    depth = len(data)
    hex_digits = width // 4

    with open(output_file, 'w') as file:
        file.write(f"WIDTH={width};\n")
        file.write(f"DEPTH={depth};\n")
        file.write("ADDRESS_RADIX=UNS;\n")
        file.write("CONTENT BEGIN\n")

        for addr, value in enumerate(data):
            value = value.zfill(hex_digits)
            file.write(f"    {addr}:{value};\n")
        file.write("END;\n")
    
    print("Arquivo gerado.")

txt_to_mif("/home/aluno/Imagens/pbl/W_in_q.hex", "/home/aluno/Imagens/pbl/data/Relu/W_in_q.mif")