import pandas as pd
import numpy as np

# Leer el CSV desde la ruta correcta
df = pd.read_csv('C:/Users/Usuario/Desktop/CoderSQL/raw/car_prices.csv')

# Filtrar solo los registros con year = 2014
df = df[df['year'] == 2014]

# Omitir filas donde vin sea NaN
df = df[df['vin'].notna()]

# Crear un diccionario para rastrear los VIN y sus sufijos
vin_counts = {}
new_vins = []

# Modificar los VIN duplicados agregando un sufijo ('b', 'c', etc.)
for vin in df['vin']:
    if vin in vin_counts:
        vin_counts[vin] += 1
        suffix = chr(ord('b') + vin_counts[vin] - 2)  # Empieza con 'b' para el segundo duplicado
        new_vin = f"{vin}{suffix}"
    else:
        vin_counts[vin] = 1
        new_vin = vin
    new_vins.append(new_vin)

# Agregar la columna modificada al DataFrame
df['vin_modified'] = new_vins

# Convertir la columna saledate al formato YYYY-MM-DD HH:MM:SS
# Primero, reemplazar NaN con una fecha por defecto para procesar
df['saledate'] = df['saledate'].fillna('Thu Jan 01 2014 00:00:00 GMT-0800 (PST)')  # Valor por defecto
df['saledate'] = df['saledate'].str.split(' GMT').str[0]  # Eliminar "GMT-0700 (PDT)"
df['saledate'] = pd.to_datetime(df['saledate'], format='%a %b %d %Y %H:%M:%S')  # Parsear la fecha
df['saledate'] = df['saledate'].dt.strftime('%Y-%m-%d %H:%M:%S')  # Convertir a formato MySQL

# Crear un archivo SQL para las sentencias INSERT
with open('insert_data_2014.sql', 'w') as f:
    f.write("USE car_prices_db;\n\n")
    f.write("SET FOREIGN_KEY_CHECKS = 0;\n\n")
    
    f.write("TRUNCATE TABLE sale;\n")
    f.write("TRUNCATE TABLE car;\n")
    f.write("TRUNCATE TABLE car_model;\n")
    f.write("TRUNCATE TABLE seller;\n")
    f.write("TRUNCATE TABLE state;\n\n")

    # Insertar en state (estados únicos)
    states = df['state'].dropna().unique()
    f.write("-- Insertar en state\n")
    for state in states:
        f.write(f"INSERT INTO state (state_name) VALUES ('{state}');\n")
    f.write("\n")

    # Insertar en seller (vendedores únicos)
    sellers = df['seller'].dropna().unique()
    f.write("-- Insertar en seller\n")
    for i, seller in enumerate(sellers):
        state_name = states[i % len(states)]  # Rotar entre estados
        seller = seller.replace("'", "''")  # Escapar comillas simples
        f.write(f"INSERT INTO seller (seller_name, state_id) VALUES ('{seller}', (SELECT state_id FROM state WHERE state_name = '{state_name}'));\n")
    f.write("\n")

    # Insertar en car_model (todas las combinaciones de make, model, trim)
    models = df[['make', 'model', 'trim']].drop_duplicates()  # No usar dropna() para incluir combinaciones con NaN
    f.write("-- Insertar en car_model\n")
    for _, row in models.iterrows():
        make = str(row['make']).replace("'", "''") if pd.notna(row['make']) else 'Unknown'
        model = str(row['model']).replace("'", "''") if pd.notna(row['model']) else 'Unknown'
        trim = str(row['trim']).replace("'", "''") if pd.notna(row['trim']) else 'NULL'
        trim_value = f"'{trim}'" if trim != 'NULL' else 'NULL'
        f.write(f"INSERT INTO car_model (make, model, trim) VALUES ('{make}', '{model}', {trim_value});\n")
    f.write("\n")

    # Insertar en car (usar vin_modified)
    f.write("-- Insertar en car\n")
    for _, row in df.iterrows():
        vin = str(row['vin_modified']).replace("'", "''")  # Usar el VIN modificado
        year = int(row['year'])
        body = str(row['body']).replace("'", "''") if pd.notna(row['body']) else 'NULL'
        body_value = f"'{body}'" if body != 'NULL' else 'NULL'
        transmission = str(row['transmission']).replace("'", "''") if pd.notna(row['transmission']) else 'NULL'
        transmission_value = f"'{transmission}'" if transmission != 'NULL' else 'NULL'
        odometer = int(row['odometer']) if pd.notna(row['odometer']) else 0
        color = str(row['color']).replace("'", "''") if pd.notna(row['color']) else 'Unknown'
        interior = str(row['interior']).replace("'", "''") if pd.notna(row['interior']) else 'Unknown'
        condition = int(row['condition']) if pd.notna(row['condition']) else 'NULL'
        condition_value = str(condition) if condition != 'NULL' else 'NULL'
        make = str(row['make']).replace("'", "''") if pd.notna(row['make']) else 'Unknown'
        model = str(row['model']).replace("'", "''") if pd.notna(row['model']) else 'Unknown'
        trim = str(row['trim']).replace("'", "''") if pd.notna(row['trim']) else 'NULL'
        trim_value = f"'{trim}'" if trim != 'NULL' else 'NULL'
        seller = str(row['seller']).replace("'", "''") if pd.notna(row['seller']) else 'Unknown'
        f.write(f"INSERT INTO car (`vin`, `year`, `body`, `transmission`, `odometer`, `color`, `interior`, `condition`, `car_model_id`, `seller_id`) VALUES "
                f"('{vin}', {year}, {body_value}, {transmission_value}, {odometer}, '{color}', '{interior}', {condition_value}, "
                f"(SELECT model_id FROM car_model WHERE make = '{make}' AND model = '{model}' AND (trim = {trim_value} OR (trim IS NULL AND {trim_value} IS NULL))), "
                f"(SELECT seller_id FROM seller WHERE seller_name = '{seller}'));\n")
    f.write("\n")

    # Insertar en sale (usar vin_modified)
    f.write("-- Insertar en sale\n")
    for _, row in df.iterrows():
        vin = str(row['vin_modified']).replace("'", "''")  # Usar el VIN modificado
        mmr = float(row['mmr']) if pd.notna(row['mmr']) else 0.0
        selling_price = float(row['sellingprice']) if pd.notna(row['sellingprice']) else 0.0
        sale_date = row['saledate']  # Ya está en formato YYYY-MM-DD HH:MM:SS, con valor por defecto si era NaN
        state_name = str(row['state']) if pd.notna(row['state']) else 'Unknown'
        f.write(f"INSERT INTO sale (vin, mmr, selling_price, sale_date, state_id) VALUES "
                f"('{vin}', {mmr}, {selling_price}, '{sale_date}', "
                f"(SELECT state_id FROM state WHERE state_name = '{state_name}'));\n")

    f.write("\nSET FOREIGN_KEY_CHECKS = 1;\n")