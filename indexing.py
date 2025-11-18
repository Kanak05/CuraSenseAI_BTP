# indexing_chroma.py (fixed for NEW Chroma API)
import json
from pathlib import Path
from sentence_transformers import SentenceTransformer
import numpy as np
from chromadb import PersistentClient   # NEW client

BATCH_SIZE = 512
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"

RAW_PATH = Path("output/chroma_raw.json")
CHROMA_DIR = Path("chroma_db")
CHROMA_DIR.mkdir(exist_ok=True)

def batchify(items, size=512):
    for i in range(0, len(items), size):
        yield items[i:i+size]

def index_collection(client, name, items, embedder):
    print(f"\nIndexing collection: {name}  ({len(items)} items)")

    # NEW API
    coll = client.get_or_create_collection(name=name)

    for batch in batchify(items, BATCH_SIZE):
        texts = [x["text"] for x in batch]
        ids = [x["id"] for x in batch]
        metas = [x["metadata"] for x in batch]

        # batch embedding
        embeds = embedder.encode(texts, batch_size=BATCH_SIZE, convert_to_numpy=True)

        coll.add(
            ids=ids,
            documents=texts,
            metadatas=metas,
            embeddings=embeds,
        )

        print(f" → Indexed batch of {len(ids)}")

def main():
    # Load raw ingestion JSON
    with open(RAW_PATH, "r", encoding="utf-8") as f:
        data = json.load(f)

    # Load embedding model
    embedder = SentenceTransformer(MODEL_NAME)

    # NEW 2024/2025 PERSISTENT CLIENT
    client = PersistentClient(path="chroma_db")

    # Index each dataset
    index_collection(client, "medicines", data["med"], embedder)
    index_collection(client, "remedies", data["rem"], embedder)
    index_collection(client, "labtests", data["lab"], embedder)
    index_collection(client, "medicalbook", data["book"], embedder)

    print("\n✔ Chroma indexing completed successfully!")

if __name__ == "__main__":
    main()
