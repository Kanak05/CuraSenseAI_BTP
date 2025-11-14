import pickle
from pathlib import Path
from llama_index.core import VectorStoreIndex, StorageContext
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

# 1. Load processed chunks (nodes)
with open("output/nodes.pkl", "rb") as f:
    nodes = pickle.load(f)

# 2. Define embedding model
embed_model = HuggingFaceEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")

# 3. Build the index
index = VectorStoreIndex(nodes, embed_model=embed_model)

# 4. Save index to disk
Path("med_index").mkdir(exist_ok=True)
index.storage_context.persist(persist_dir="med_index")

print("✅ Index successfully built and saved to 'med_index/'")
