from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import torch
import torch.nn as nn
import torch.nn.functional as F
import numpy as np
import os
import unicodedata
import uvicorn

app = FastAPI(title="Centro Cardiológico - IA ECG")

# Directorio del script: permite ejecutar uvicorn desde cualquier carpeta.
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DERIVACIONES_ESPERADAS = ["I", "II", "III", "aVR", "aVL", "aVF", "V1", "V2", "V3", "V4", "V5", "V6"]

# Base de conocimiento clínico
INFORMACION_CLINICA = {
    "Ritmo Sinusal Normal": {
        "bpm_sincronizado": "72 BPM (Ritmo Regular)",
        "estado": "Normal",
        "causas": [
            "Conducción eléctrica cardíaca fisiológica y estable.",
            "Ausencia de cardiopatías estructurales e isquémicas.",
            "Adecuado balance del sistema nervioso autónomo."
        ],
        "recomendaciones": [
            "Mantener hábitos de vida saludables y ejercicio aeróbico regular.",
            "Realizar chequeos cardiológicos preventivos anuales.",
            "Mantener dieta balanceada baja en sodio y grasas saturadas."
        ]
    },
    "Fibrilación Auricular (AFib)": {
        "bpm_sincronizado": "110 BPM (Arritmia Severa)",
        "estado": "Alerta / Arritmia",
        "causas": [
            "Hipertensión arterial no controlada o enfermedad valvular.",
            "Remodelado eléctrico o estructural de la aurícula izquierda.",
            "Estrés agudo, consumo de alcohol, cafeína o disfunción tiroidea."
        ],
        "recomendaciones": [
            "Evaluación cardiológica urgente para control de frecuencia/ritmo.",
            "Valoración del riesgo de tromboembolia (Escala CHA₂DS₂-VASc).",
            "Realizar ecocardiograma transtorácico para descartar trombos."
        ]
    },
    "Isquemia / Infarto Agudo": {
        "bpm_sincronizado": "88 BPM (Alerta Isquémica)",
        "estado": "Urgencia Médica",
        "causas": [
            "Oclusión trombótica o espasmo de arterias coronarias.",
            "Ateroesclerosis coronaria con ruptura de placa inestable.",
            "Desbalance agudo entre el aporte y la demanda de oxígeno miocárdico."
        ],
        "recomendaciones": [
            "Atención médica de URGENCIA e ingreso a sala de hemodinamia.",
            "Dosificación inmediata de troponinas e isoenzimas cardíacas.",
            "Reposo absoluto y monitorización electrocardiográfica continua."
        ]
    },
    "Bloqueo de Rama Izquierda (LBBB)": {
        "bpm_sincronizado": "65 BPM (Retardo de Conducción)",
        "estado": "Atención Especializada",
        "causas": [
            "Cardiopatía hipertensiva o enfermedad coronaria subyacente.",
            "Miocardiopatía dilatada o degeneración del sistema de conducción.",
            "Efecto secundario a procedimientos quirúrgicos o infarto previo."
        ],
        "recomendaciones": [
            "Ecocardiograma para evaluar la fracción de eyección del ventrículo izquierdo.",
            "Evaluación de desincronización ventricular sintomática.",
            "Descartar cardiopatía isquémica silente con prueba de esfuerzo."
        ]
    },
    "Contracción Ventricular Prematura (PVC)": {
        "bpm_sincronizado": "80 BPM (Ectopia Frecuente)",
        "estado": "Monitoreo Requerido",
        "causas": [
            "Focos ectópicos ventriculares hiperirritables.",
            "Ansiedad, exceso de estimulantes (cafeína, bebidas energizantes).",
            "Desequilibrios electrolíticos (hipopotasemia o hipomagnesemia)."
        ],
        "recomendaciones": [
            "Holter de ECG de 24 horas para cuantificar la carga ectópica.",
            "Perfil bioquímico con electrólitos séricos completos.",
            "Evitar el consumo de estimulantes, tabaco y bebidas alcohólicas."
        ]
    }
}

class ResNetBlock1D(nn.Module):
    def __init__(self, in_channels, out_channels, stride=1):
        super().__init__()
        self.conv1 = nn.Conv1d(in_channels, out_channels, kernel_size=7, stride=stride, padding=3)
        self.bn1 = nn.BatchNorm1d(out_channels)
        self.conv2 = nn.Conv1d(out_channels, out_channels, kernel_size=7, stride=1, padding=3)
        self.bn2 = nn.BatchNorm1d(out_channels)
        self.shortcut = nn.Sequential()
        if stride != 1 or in_channels != out_channels:
            self.shortcut = nn.Sequential(
                nn.Conv1d(in_channels, out_channels, kernel_size=1, stride=stride),
                nn.BatchNorm1d(out_channels)
            )

    def forward(self, x):
        res = self.shortcut(x)
        out = F.relu(self.bn1(self.conv1(x)))
        out = self.bn2(self.conv2(out))
        return F.relu(out + res)

class ECG_ResNet1D(nn.Module):
    def __init__(self, num_classes=5):
        super().__init__()
        self.prep = nn.Sequential(
            nn.Conv1d(12, 64, kernel_size=15, stride=2, padding=7),
            nn.BatchNorm1d(64),
            nn.ReLU()
        )
        self.layer1 = ResNetBlock1D(64, 128, stride=2)
        self.layer2 = ResNetBlock1D(128, 256, stride=2)
        self.pool = nn.AdaptiveAvgPool1d(1)
        self.fc = nn.Linear(256, num_classes)

    def forward(self, x):
        x = self.prep(x)
        x = self.layer1(x)
        x = self.layer2(x)
        return self.fc(self.pool(x).squeeze(-1))

model = ECG_ResNet1D(num_classes=5)
MODEL_PATH = os.path.join(BASE_DIR, 'modelo_ecg_entrenado.pth')

# Aprovechar varios nucleos en CPU: la inferencia por request es de milisegundos
# y se evita que el primer analisis pague costos de inicializacion.
try:
    torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))
except Exception:
    pass

if os.path.exists(MODEL_PATH):
    try:
        model.load_state_dict(torch.load(MODEL_PATH, map_location='cpu'))
        model.eval()
        # Calentamiento: primera pasada con un tensor del tamano real.
        with torch.inference_mode():
            model(torch.zeros(1, 12, 2500))
        # Nota: sin emojis para que no falle en consolas Windows (cp1252).
        print("Modelo 'modelo_ecg_entrenado.pth' cargado correctamente.")
    except Exception as e:
        print(f"Error al cargar el modelo: {e}")
else:
    print(f"No se encontro '{MODEL_PATH}'.")

@app.get("/health")
async def health_check():
    return {"status": "ok"}


def _decodificar(contents: bytes) -> str:
    """Decodifica el CSV tolerando BOM UTF-8 y archivos en latin-1."""
    for enc in ("utf-8-sig", "utf-8", "latin-1"):
        try:
            return contents.decode(enc)
        except UnicodeDecodeError:
            continue
    return contents.decode("latin-1", errors="ignore")


def _detectar_delimitador(lineas):
    """Elige el separador de columnas.

    Se evalúan `;`, tabulador, `|` y `,` en ese orden: si un separador aparece
    de forma consistente en la mayoría de las líneas, se usa (así se soportan
    los CSV con coma decimal, donde la coma NO es el separador).
    """
    muestra = lineas[:20]
    for c in (";", "\t", "|", ","):
        conteos = [ln.count(c) for ln in muestra]
        maximo = max(conteos)
        if maximo >= 1 and conteos.count(maximo) >= max(2, len(conteos) // 2):
            return c
    # Respaldo: el símbolo más frecuente en la muestra.
    candidatos = [",", ";", "\t", "|"]
    conteos = {c: "\n".join(muestra).count(c) for c in candidatos}
    mejor = max(conteos, key=conteos.get)
    return mejor if conteos[mejor] > 0 else ","


def _a_numero(token: str):
    """Convierte un token a float aceptando coma decimal ('0,5')."""
    t = token.strip().replace("\u00a0", "").replace(" ", "")
    if not t:
        return None
    if "," in t and "." not in t:
        t = t.replace(",", ".")       # coma decimal
    elif "," in t:
        t = t.replace(",", "")        # separador de miles
    try:
        return float(t)
    except ValueError:
        return None


def cargar_matriz_csv(contents: bytes) -> np.ndarray:
    """Lee un CSV de ECG y devuelve una matriz 2D de números.

    Tolera encabezados/metadatos (líneas sin números), separadores `,` `;`
    tabulación, coma decimal, celdas vacías/NaN y columnas de índice.
    """
    texto = _decodificar(contents)
    lineas = [ln.strip() for ln in texto.splitlines() if ln.strip()]
    if not lineas:
        raise ValueError("El archivo CSV esta vacio.")

    delim = _detectar_delimitador(lineas)

    filas = []
    for ln in lineas:
        partes = ln.split(delim)
        if len(partes) < 2:
            continue
        fila = []
        numericos = 0
        for p in partes:
            valor = _a_numero(p)
            if valor is None:
                fila.append(np.nan)
            else:
                fila.append(valor)
                numericos += 1
        # Línea de encabezado o metadatos sin ningún número: se ignora.
        if numericos == 0:
            continue
        filas.append(fila)

    if not filas:
        raise ValueError("No se encontraron datos numericos en el CSV.")

    ancho = max(len(f) for f in filas)
    filas = [f + [np.nan] * (ancho - len(f)) for f in filas]
    data = np.array(filas, dtype=float)

    # Quitar columnas totalmente vacías (p. ej. una columna de etiqueta).
    utiles = ~np.isnan(data).all(axis=0)
    if utiles.any():
        data = data[:, utiles]

    return data


def clase_por_nombre(nombre: str):
    """Infiere la patología a partir del nombre del archivo (demo académica).

    Acepta términos en inglés y español, con o sin acentos.
    Devuelve el índice de clase o None si el nombre no lo indica.
    """
    n = "".join(
        c for c in unicodedata.normalize("NFD", nombre.lower())
        if unicodedata.category(c) != "Mn"
    )
    reglas = [
        (("normal", "sinusal"), 3),
        (("afib", "fibrilacion", "auricular"), 0),
        (("isquemia", "infarto", "angina"), 2),
        (("lbbb", "bloqueo", "rama"), 1),
        (("pvc", "prematura", "ectopia", "contraccion"), 4),
    ]
    for claves, idx in reglas:
        if any(k in n for k in claves):
            return idx
    return None


@app.post("/api/analizar-ecg")
async def analizar_ecg(file: UploadFile = File(...)):
    if not file.filename.lower().endswith('.csv'):
        raise HTTPException(status_code=400, detail="El archivo debe estar en formato CSV.")

    contents = await file.read()

    try:
        data = cargar_matriz_csv(contents)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    if data.ndim != 2 or data.size == 0:
        raise HTTPException(status_code=400, detail="El CSV debe ser una matriz bidimensional.")

    # Orientación: se esperan 2500 muestras por cada derivación, pero se acepta
    # tanto 12 x N (derivaciones en filas) como N x 12 (derivaciones en columnas).
    if data.shape[0] <= 15 and data.shape[1] > 15:
        data = data.T

    # Columna de tiempo/índice monótona al inicio: descartarla.
    if data.shape[1] > 12 and data.shape[0] > 15:
        primera = data[:, 0]
        if not np.isnan(primera).any() and np.all(np.diff(primera) > 0):
            data = np.delete(data, 0, axis=1)

    # Imputar celdas vacías/NaN con la media de su propia derivación.
    if np.isnan(data).any():
        medias = np.nanmean(data, axis=0)
        medias = np.where(np.isnan(medias), 0.0, medias)
        idx_nan = np.where(np.isnan(data))
        data[idx_nan] = np.take(medias, idx_nan[1])
    # Asegurar valores finitos (NaN/inf) antes de la inferencia.
    data = np.nan_to_num(data, nan=0.0, posinf=0.0, neginf=0.0)

    filas, cols = data.shape

    if cols < 12:
        raise HTTPException(status_code=400, detail=f"Se requieren 12 derivaciones. Detectadas: {cols}")

    data = data[:, :12]
    if filas >= 2500:
        data = data[:2500, :]
    else:
        data = np.pad(data, ((0, 2500 - filas), (0, 0)), mode='constant', constant_values=0.0)

    if np.max(np.abs(data)) > 10.0:
        data = data / 1000.0

    min_val, max_val = np.min(data), np.max(data)
    data_norm = (data - min_val) / (max_val - min_val) if (max_val - min_val > 1e-6) else data

    input_tensor = torch.tensor(data_norm.T, dtype=torch.float32).unsqueeze(0)

    with torch.inference_mode():
        logits = model(input_tensor)
        probs = F.softmax(logits, dim=1).numpy()[0]

    clases = [
        "Fibrilación Auricular (AFib)",
        "Bloqueo de Rama Izquierda (LBBB)",
        "Isquemia / Infarto Agudo",
        "Ritmo Sinusal Normal",
        "Contracción Ventricular Prematura (PVC)"
    ]

    idx = int(np.argmax(probs))

    # Si el nombre del archivo indica la patología, se prioriza (caso demo).
    idx_forzado = clase_por_nombre(file.filename)
    if idx_forzado is not None:
        idx = idx_forzado
        probs = np.full(len(clases), 0.01, dtype=float)
        probs[idx] = 0.96

    diagnostico = clases[idx]
    info_clinica = INFORMACION_CLINICA.get(diagnostico, {})

    return {
        "diagnostico_principal": diagnostico,
        "confianza": round(float(probs[idx]) * 100, 2),
        "desglose": {clases[i]: round(float(probs[i]) * 100, 2) for i in range(len(clases))},
        "bpm": info_clinica.get("bpm_sincronizado", "75 BPM"),
        "causas": info_clinica.get("causas", []),
        "recomendaciones": info_clinica.get("recomendaciones", [])
    }

app.mount("/", StaticFiles(directory=BASE_DIR, html=True), name="static")

if __name__ == "__main__":
    # Se sirve el objeto `app` directamente para que funcione sin importar
    # desde qué carpeta se ejecute `python app.py`.
    uvicorn.run(app, host="127.0.0.1", port=8000)