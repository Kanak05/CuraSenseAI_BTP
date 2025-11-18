from fastapi import FastAPI, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import shutil, os

# Import only what exists in rag_pipeline
from rag_pipeline import query_rag, extract_text

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
    allow_origins=["*"],
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
    Route that accepts a prompt and optional PDF file for RAG querying.
    """
    temp_path = None
    try:
        # If a file is uploaded, save it temporarily
        if file:
            temp_path = f"temp_{file.filename}"
            with open(temp_path, "wb") as f:
                shutil.copyfileobj(file.file, f)
            print(f"[generate] Saved uploaded file to {temp_path}")

        # Run RAG query
        response_text = query_rag(prompt, pdf_path=temp_path)
        print(f"[generate] query_rag returned {len(response_text)} chars")

        return {"text": response_text}

    except Exception as e:
        print(f"[generate] Error: {e}")
        return {"text": f"Error: {e}"}

    finally:
        # Cleanup temporary PDF
        if temp_path and os.path.exists(temp_path):
            os.remove(temp_path)
            print(f"[generate] Deleted temp file {temp_path}")


@app.post("/extract")
async def extract_only(file: UploadFile = File(...)):
    temp_path = f"temp_{file.filename}"
    with open(temp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    extracted_text = extract_text(temp_path)

    os.remove(temp_path)
    return {"extracted_text": extracted_text[:5000]}  # return first 5k chars
