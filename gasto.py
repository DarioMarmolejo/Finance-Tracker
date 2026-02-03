import requests # Equivalente a HttpClient en Java
import json
from datetime import datetime

# CONFIGURACIÓN
# Ojo: Usamos la URL de prueba de n8n por ahora.
# Cuando actives el flujo ("Activate"), cambiarás esto por la URL de producción.
WEBHOOK_URL = "http://localhost:5678/webhook/gasto"

def main():
    print("--- 💸 REGISTRADOR DE GASTOS (Malo's Tracker) ---")
    
    # 1. Capturar datos (Inputs)
    try:
        descripcion = input("Concepto (ej. Gasolina): ")
        monto = float(input("Monto: "))
        
        # Simulamos un menú simple de categorías
        print("\nCategorías: [1] Alimentos  [2] Transporte  [3] Servicios")
        cat_id = int(input("ID Categoría (Enter para 1): ") or 1)
        
        # Armamos el objeto (Diccionario en Python = Map en Java)
        payload = {
            "monto": monto,
            "tipo": "EGRESO",
            "desc": descripcion,
            "cuenta_id": 1,      # Por defecto Efectivo
            "categoria_id": cat_id,
            "fecha": datetime.now().isoformat()
        }

        # 2. Enviar a n8n
        print(f"\nEnviando a n8n... ", end="")
        response = requests.post(WEBHOOK_URL, json=payload)

        # 3. Validar respuesta
        if response.status_code == 200:
            data = response.json()
            # n8n nos devuelve el array de items, tomamos el primero
            nuevo_id = data.get('id', 'N/A') 
            print(f"✅ ¡Éxito! Gasto registrado con ID: {nuevo_id}")
        else:
            print(f"❌ Error {response.status_code}: {response.text}")

    except ValueError:
        print("❌ Error: Por favor ingresa números válidos para el monto.")
    except Exception as e:
        print(f"❌ Error inesperado: {e}")

if __name__ == "__main__":
    main()