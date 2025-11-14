import re
import fitz
import pickle
import os
from pathlib import Path
from llama_index.core import (
    VectorStoreIndex,
    StorageContext,
    load_index_from_storage,
)
from llama_index.core.query_engine import RetrieverQueryEngine
from llama_index.core.prompts import PromptTemplate
from llama_index.embeddings.huggingface import HuggingFaceEmbedding
from llama_index.llms.llama_cpp import LlamaCPP
from llama_index.core.settings import Settings
import pytesseract
from PIL import Image

# Explicitly set Tesseract path (important for Windows)
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"


# -------------------------------
# CONFIG
# -------------------------------
EMBED_MODEL = "sentence-transformers/all-MiniLM-L6-v2"
MODEL_PATH = "models/google_gemma-3-270m-it-Q4_0.gguf"
INDEX_DIR = "./med_index"
NODE_FILE = "output/nodes.pkl"

# -------------------------------
# LOAD NODES
# -------------------------------
def load_nodes(node_file: str):
    if not os.path.exists(node_file):
        raise FileNotFoundError(f"❌ Node file not found: {node_file}")
    with open(node_file, "rb") as f:
        nodes = pickle.load(f)
    print(f"✅ Loaded {len(nodes)} nodes from {node_file}")
    return nodes


# -------------------------------
# BUILD OR LOAD INDEX
# -------------------------------
def build_or_load_index(nodes, embed_model, persist_dir):
    persist_path = Path(persist_dir)
    if persist_path.exists() and any(persist_path.iterdir()):
        print("[INFO] Loading existing index...")
        storage = StorageContext.from_defaults(persist_dir=persist_dir)
        index = load_index_from_storage(storage)
    else:
        print("[INFO] Building new index...")
        storage = StorageContext.from_defaults()
        index = VectorStoreIndex.from_documents(nodes, storage_context=storage, embed_model=embed_model)
        storage.persist(persist_dir=persist_dir)
        print(f"✅ Index built and saved to {persist_dir}")
    return index


# -------------------------------
# RESPONSE CLEANER
# -------------------------------
def clean_response(text: str):
    text = re.sub(r'\b(Final Answer|The answer is|Answer:|Furthermore|In conclusion|Therefore)\b[:\s-]*', '', text, flags=re.IGNORECASE)
    sentences = re.split(r'(?<=[.!?])\s+', text)
    seen, cleaned = set(), []
    for s in sentences:
        s_clean = s.strip()
        if s_clean and s_clean not in seen:
            seen.add(s_clean)
            cleaned.append(s_clean)
    text = " ".join(cleaned)
    text = re.sub(r'\b(or the|and the)\b\s*$', '', text.strip())
    if not text.endswith('.'):
        text += '.'
    return text


# -------------------------------
# SETUP PIPELINE
# -------------------------------
def setup_pipeline():
    print("🚀 Setting up RAG pipeline...")

    embed_model = HuggingFaceEmbedding(model_name=EMBED_MODEL)
    Settings.embed_model = embed_model

    nodes = load_nodes(NODE_FILE)
    index = build_or_load_index(nodes, embed_model, INDEX_DIR)

    llm = LlamaCPP(
        model_path=MODEL_PATH,
        context_window=2048,
        temperature=0.2,
        max_new_tokens=512,
        verbose=False,
    )
    Settings.llm = llm

    prompt_template = PromptTemplate(
        "You are a knowledgeable and caring medical assistant.\n"
        "Read the context carefully and answer the question in a structured, human-readable way.\n\n"
        "Follow this format:\n"
        "1️⃣ **Brief Overview** – A one-line summary of the main topic.\n"
        "2️⃣ **Detailed Explanation** – 3–5 bullet points covering key facts or findings.\n"
        "3️⃣ **Symptoms / Causes / Treatment (if relevant)** – Mention only if applicable.\n"
        "4️⃣ **Final Summary** – A short closing sentence summarizing the key takeaway.\n\n"
        "Rules:\n"
        "- Use bullet points and headings with emojis (✅, ⚕️, 💡, 🧠) when appropriate.\n"
        "- Avoid repeating phrases or rephrasing the question.\n"
        "- Write naturally, as if explaining to a patient or student.\n"
        "- If there is no relevant information, respond with: 'I don't know.'\n\n"
        "Context:\n{context_str}\n\n"
        "Question: {query_str}\n\n"
        "Answer:"
    )
    # print(prompt_template)

    retriever = index.as_retriever(similarity_top_k=5)
    query_engine = RetrieverQueryEngine.from_args(
        retriever,
        llm=llm,
        text_qa_template=prompt_template,
        llm_kwargs={"temperature": 0.2, "top_p": 0.8, "repeat_penalty": 1.2},
    )

    print("✅ RAG pipeline ready.")
    return query_engine, prompt_template


# Initialize pipeline globally (only once)
query_engine, PROMPT_TEMPLATE = setup_pipeline()


# -------------------------------
# PDF EXTRACTOR (with OCR fallback)
# -------------------------------
import pytesseract
from PIL import Image

def extract_text(pdf_path, max_chars=1500):
    """
    Extract text from a PDF file.
    Uses direct text extraction first; falls back to OCR if the PDF is image-based.
    """
    if not os.path.exists(pdf_path):
        print(f"[WARN] PDF path not found: {pdf_path}")
        return ""

    text = ""
    try:
        doc = fitz.open(pdf_path)
        if doc.page_count == 0:
            print(f"[WARN] Empty PDF: {pdf_path}")
            return ""

        for page in doc:
            # Try direct text extraction
            page_text = page.get_text("text")

            # If page has no selectable text, run OCR
            if not page_text.strip():
                print(f"[INFO] Running OCR on page {page.number + 1} (no text layer found)...")
                pix = page.get_pixmap()
                img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
                page_text = pytesseract.image_to_string(img)

            text += page_text + "\n"

            # Stop if enough text collected
            if len(text) > max_chars:
                break
        doc.close()

    except Exception as e:
        print(f"[ERROR] Failed to extract text from PDF: {e}")

    print(f"[DEBUG] Extracted {len(text)} characters from {pdf_path}")
    return text[:max_chars]


# -------------------------------
# MAIN PIPELINE
# -------------------------------
def query_rag(query: str, pdf_path: str = None):
    print(f"[DEBUG] query_rag called with pdf_path={pdf_path}")
    extra_context = ""
    if pdf_path:
        extra_context = extract_text(pdf_path)
        if extra_context.strip():
            with open("last_extracted_text.txt", "w", encoding="utf-8") as f:
                f.write(extra_context)
        # print(f"\n📄 Extracted text from {pdf_path}:\n{extra_context[:1000]}")
        query = f"{query}\nInclude this information:\n{extra_context}"

    try:
        retriever = query_engine.retriever
        retrieved_nodes = retriever.retrieve(query)
        context_str = "\n\n".join([getattr(node, "text", str(node)) for node in retrieved_nodes])
        if extra_context.strip():
            context_str = (
                # f"📄 Extracted Document Text:\n{extra_context}\n\n"
                f"🧠 Retrieved Knowledge Base Context:\n{context_str}"
            )
        else:
            context_str = f"🧠 Retrieved Knowledge Base Context:\n{context_str}"

        prompt_preview = PROMPT_TEMPLATE.format(context_str=context_str, query_str=query)
        # print("\n==============================")
        # print("🧠 PROMPT SENT TO LLM:\n")
        # print(prompt_preview)
        # print("==============================\n")
        with open("last_prompt.txt", "w", encoding="utf-8") as f:
            f.write(prompt_preview)
    except Exception as e:
        print(f"[WARN] Could not print LLM prompt: {e}")

    response = query_engine.query(query)
    final_answer = clean_response(str(response))

    # Remove duplicates line by line
    # lines = final_answer.splitlines()
    # seen, unique_lines = set(), []
    # for line in lines:
    #     if line.strip() and line not in seen:
    #         seen.add(line)
    #         unique_lines.append(line.strip())
    # return " ".join(unique_lines)
    return final_answer


if __name__ == "__main__":
    response = query_rag("What is diabetes?")
    print("\n✅ Final Answer:\n", response)
