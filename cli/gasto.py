import requests
import json
import os
from datetime import datetime

# Configuración dinámica del Host
N8N_HOST = os.getenv('N8N_HOST', 'localhost')
WEBHOOK_URL = f"http://{N8N_HOST}:5678/webhook/gasto"

def main():
    print("--- 💸 REGISTRADOR DE GASTOS (Malo's Tracker) ---")
    
    try:
        descripcion = input("Concepto (ej. Gasolina): ")
        if not descripcion:
            print("❌ El concepto no puede estar vacío.")
            return

        monto_str = input("Monto: ")
        monto = float(monto_str)
        
        print("\nCategorías: [1] Alimentos  [2] Transporte  [3] Servicios")
        cat_input = input("ID Categoría (Enter para 1): ")
        cat_id = int(cat_input) if cat_input else 1
        
        payload = {
            "monto": monto,
            "tipo": "EGRESO",
            "desc": descripcion,
            "cuenta_id": 1,
            "categoria_id": cat_id,
            "fecha": datetime.now().isoformat()
        }

        # flush=True fuerza a que el texto aparezca inmediatamente en pantalla
        print(f"\nEnviando a n8n... ", end="", flush=True)
        
        response = requests.post(WEBHOOK_URL, json=payload, timeout=10)

        if response.status_code == 200:
            try:
                data = response.json()
                # Lógica robusta para encontrar el ID
                nuevo_id = "N/A"
                if isinstance(data, list) and len(data) > 0:
                    nuevo_id = data[0].get('id', 'N/A')
                elif isinstance(data, dict):
                    nuevo_id = data.get('id', 'N/A')
                
                print(f"✅ ¡Éxito! Gasto registrado con ID: {nuevo_id}")
            except Exception as json_error:
                print(f"⚠️ Guardado, pero respuesta extraña: {response.text}")
        else:
            print(f"❌ Error del servidor ({response.status_code}): {response.text}")

    except ValueError:
        print("\n❌ Error: El monto debe ser un número válido.")
    except Exception as e:
        print(f"\n❌ Error inesperado: {e}")

if __name__ == "__main__":
    main()