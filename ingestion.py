import fitz
import pickle
from pathlib import Path
from llama_index.core import Document
from llama_index.core.node_parser import SemanticSplitterNodeParser
from llama_index.embeddings.huggingface import HuggingFaceEmbedding

PDF_PATH = "data/Medical_book.pdf"
embed_model = HuggingFaceEmbedding(model_name="sentence-transformers/all-MiniLM-L6-v2")

def extract_and_chunk(pdf_path):
    doc = fitz.open(pdf_path)
    pages = []
    for i, page in enumerate(doc):
        text = page.get_text()
        if len(text.strip()) > 100:
            pages.append(Document(text=text, metadata={"page": i + 1}))
    doc.close()

    # splitter = SemanticSplitterNodeParser(chunk_size=300, chunk_overlap=50)
    splitter = SemanticSplitterNodeParser(
        embed_model=embed_model,
        chunk_size=300,
        chunk_overlap=50
    )
    nodes = splitter.get_nodes_from_documents(pages)
    print(f"Extracted {len(pages)} pages → {len(nodes)} chunks")

    Path("output").mkdir(exist_ok=True)
    with open("output/nodes.pkl", "wb") as f:
        pickle.dump(nodes, f)
    print("Saved nodes.pkl")

if __name__ == "__main__":
    extract_and_chunk(PDF_PATH)
