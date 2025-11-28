import pandas as pd

# 1. Ler arquivo
df = pd.read_excel("data/ori-dest.xlsx")

# 2. Arredondar coordenadas (opcional, mas recomendado)
df["Lat_ori"] = df["Lat_ori"].astype(float).round(6)
df["Long_ori"] = df["Long_ori"].astype(float).round(6)
df["Lat_dest"] = df["Lat_dest"].astype(float).round(6)
df["Long_dest"] = df["Long_dest"].astype(float).round(6)

# 3. Criar chave padrão lat_long para origem e destino
df["origin"] = df["Lat_ori"].astype(str) + "_" + df["Long_ori"].astype(str)
df["destination"] = df["Lat_dest"].astype(str) + "_" + df["Long_dest"].astype(str)

# 4. Salvar arquivo final
df.to_excel("data/ori-dest-com-chaves.xlsx", index=False)

print("Arquivo gerado: ori-dest-com-chaves.xlsx")
