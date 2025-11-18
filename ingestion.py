# ingestion_chroma.py
import fitz
import pandas as pd
from pathlib import Path
import json

DATA_DIR = Path("data")
OUT_DIR = Path("output")
OUT_DIR.mkdir(exist_ok=True)

MEDICINE_XLSX = DATA_DIR / "MID.xlsx"
REMEDIES_CSV = DATA_DIR / "Home Remedies.csv"
LAB_TEST_CSV = DATA_DIR / "lab_report_master.csv"
PDF_PATH = DATA_DIR / "Medical_book.pdf"

def load_medicines():
    df = pd.read_excel(MEDICINE_XLSX).fillna("")
    docs = []

    for idx, r in df.iterrows():
        text_parts = []
        for col in r.index:
            val = str(r[col]).strip()
            if val:
                text_parts.append(f"{col}: {val}")
                
        docs.append({
            "id": f"med_{idx}",
            "text": "\n".join(text_parts),
            "metadata": {"source": "medicine", "row": int(idx)}
        })

    print(f"Loaded {len(docs)} medicines")
    return docs

def load_remedies():
    df = pd.read_csv(REMEDIES_CSV).fillna("")
    docs = []

    for idx, r in df.iterrows():
        parts = []
        for col in r.index:
            val = str(r[col]).strip()
            if val:
                parts.append(f"{col}: {val}")

        docs.append({
            "id": f"rem_{idx}",
            "text": "\n".join(parts),
            "metadata": {"source": "remedy", "row": int(idx)}
        })

    print(f"Loaded {len(docs)} remedies")
    return docs

def load_labtests():
    df = pd.read_csv(LAB_TEST_CSV).fillna("")
    docs = []

    for idx, r in df.iterrows():
        t = (
            f"{r['Parameter']} ({r['Category']})\n"
            f"Male Range: {r['Male Range']}\n"
            f"Female Range: {r['Female Range']}\n"
            f"Child Range: {r['Child Range']}\n"
            f"Neonate Range: {r['Neonate Range']}\n"
            f"Units: {r['SI Unit']} ({r['Conventional Unit']})\n"
            f"Interpretation: {r['Interpretation']}"
        )

        docs.append({
            "id": f"lab_{idx}",
            "text": t,
            "metadata": {
                "source": "labtest",
                "parameter": r["Parameter"],
                "category": r["Category"]
            }
        })

    print(f"Loaded {len(docs)} lab tests")
    return docs

def load_pdf():
    doc = fitz.open(str(PDF_PATH))
    docs = []
    for i, page in enumerate(doc):
        text = page.get_text("text")
        if len(text.strip()) < 200:
            continue
        docs.append({
            "id": f"book_{i}",
            "text": text,
            "metadata": {"source": "book", "page": i+1}
        })
    print(f"Loaded {len(docs)} book pages")
    return docs

def run_ingestion():
    data = {
        "med": load_medicines(),
        "rem": load_remedies(),
        "lab": load_labtests(),
        "book": load_pdf()
    }

    with open(OUT_DIR / "chroma_raw.json", "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)

    print("Saved raw docs → output/chroma_raw.json")
    return data


if __name__ == "__main__":
    run_ingestion()
