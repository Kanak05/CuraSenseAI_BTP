from fastapi import FastAPI, UploadFile, File,  Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import shutil, os

from rag_pipeline import query_rag , query_engine  # reuse the pipeline initialized in rag_pipeline
# -------------------------------
# Initialize the FastAPI app
# -------------------------------
app = FastAPI(
    title="Medical Assistant Backend",
    description="Unified API for report analysis, question answering, and text generation",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],      # allow all domains (frontend, mobile, etc.)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# -------------------------------
# SCHEMA DEFINITIONS
# -------------------------------
class Prompt(BaseModel):
    prompt: str
    pdf_path: str = ""


# -------------------------------
# ROUTES
# -------------------------------

@app.get("/")
def root():
    return {"message": "Backend running successfully!"}


@app.post("/generate")
async def generate(prompt: str = Form(...), file: UploadFile = File(None)):
    """
    General-purpose route that accepts a prompt and optional PDF file.
    """
    temp_path = None

    try:
        # Save uploaded PDF if present
        if file:
            temp_path = f"temp_{file.filename}"
            with open(temp_path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            print(f"[generate] Saved uploaded file to {temp_path}")

        # Query the RAG pipeline (with or without PDF)
        text = query_rag(prompt, pdf_path=temp_path)
        print(f"[generate] query_rag returned {len(text)} chars")

        return {"text": text}

    except Exception as e:
        print(f"[generate] Error: {e}")
        return {"text": f"Error: {e}"}

    finally:
        # Clean up temporary file
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)
            print(f"[generate] Deleted temp file {temp_path}")

@app.post("/extract")
async def extract_only(file: UploadFile = File(...)):
    temp_path = f"temp_{file.filename}"
    with open(temp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    from rag_pipeline import extract_text
    text = extract_text(temp_path)
    os.remove(temp_path)
    return {"extracted_text": text[:5000]}  # return first 5k chars
