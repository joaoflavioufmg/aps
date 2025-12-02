import pandas as pd

# 1. Ler o arquivo original
df = pd.read_excel("data/Dados-LS.xlsx")

#import pandas as pd
# 1. Ler arquivo original
df = pd.read_excel("data/Dados-LS.xlsx")

# 2. Arredondar Lat e Long para 6 casas decimais
df["Lat"] = df["Lat"].astype(float).round(6)
df["Long"] = df["Long"].astype(float).round(6)

# 3. Criar chave texto: lat-long
df["lat_long"] = df["Lat"].astype(str) + "_" + df["Long"].astype(str)

# 4. Salvar novo arquivo
df.to_excel("data/Dados-LS-6casas.xlsx", index=False)
print("Arquivo gerado: Dados-LS-6casas.xlsx")
