from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import chromadb
import requests
import shutil
import os
from pypdf import PdfReader
from typing import Optional

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection("documents")

OLLAMA_CHAT = "http://localhost:11434/api/generate"
OLLAMA_EMBED = "http://localhost:11434/api/embeddings"
OLLAMA_TAGS = "http://localhost:11434/api/tags"
POLICIES_DIR = "./policies"

os.makedirs(POLICIES_DIR, exist_ok=True)


class HistoryMessage(BaseModel):
    role: str
    content: str


class ChatRequest(BaseModel):
    question: str
    model: Optional[str] = "llama3.2"
    history: Optional[list[HistoryMessage]] = []
    filter_sources: Optional[list[str]] = None


def get_embedding(text):
    response = requests.post(
        OLLAMA_EMBED,
        json={"model": "nomic-embed-text", "prompt": text}
    )
    data = response.json()
    if "error" in data:
        raise RuntimeError(f"Embedding error: {data['error']}")
    return data["embedding"]


def ingest_pdf(filepath: str):
    filename = os.path.basename(filepath)
    reader = PdfReader(filepath)
    text = "".join(page.extract_text() or "" for page in reader.pages)
    chunks = [c for c in text.split("\n\n") if c.strip()]
    for idx, chunk in enumerate(chunks):
        embedding = get_embedding(chunk)
        collection.add(
            ids=[f"{filename}-{idx}"],
            documents=[chunk],
            embeddings=[embedding],
            metadatas=[{"source": filename}]
        )


@app.get("/models")
def list_models():
    try:
        response = requests.get(OLLAMA_TAGS, timeout=5)
        names = [m["name"] for m in response.json().get("models", [])]
        return {"models": names}
    except Exception:
        return {"models": ["llama3.2"]}


@app.get("/documents")
def list_documents():
    files = [f for f in os.listdir(POLICIES_DIR) if f.endswith(".pdf")]
    return {"documents": files}


@app.post("/upload")
async def upload_document(file: UploadFile = File(...)):
    if not file.filename.endswith(".pdf"):
        raise HTTPException(status_code=400, detail="Only PDF files are supported")

    dest = os.path.join(POLICIES_DIR, file.filename)
    with open(dest, "wb") as f:
        shutil.copyfileobj(file.file, f)

    try:
        ingest_pdf(dest)
    except Exception as e:
        os.remove(dest)
        raise HTTPException(status_code=500, detail=f"Ingestion failed: {str(e)}")

    return {"message": f"{file.filename} uploaded and ingested successfully"}


@app.delete("/documents/{filename}")
def delete_document(filename: str):
    filepath = os.path.join(POLICIES_DIR, filename)
    if not os.path.exists(filepath):
        raise HTTPException(status_code=404, detail="File not found")

    os.remove(filepath)
    results = collection.get(where={"source": filename})
    if results["ids"]:
        collection.delete(ids=results["ids"])

    return {"message": f"{filename} deleted successfully"}


@app.post("/ask")
def ask(request: ChatRequest):
    embedding = get_embedding(request.question)

    query_kwargs = {"query_embeddings": [embedding], "n_results": 3}
    if request.filter_sources:
        query_kwargs["where"] = {"source": {"$in": request.filter_sources}}

    results = collection.query(**query_kwargs)
    contexts = results["documents"][0]
    sources = list({item["source"] for item in results["metadatas"][0]})
    context_text = "\n".join(contexts)

    history_text = ""
    if request.history:
        for msg in request.history[-6:]:
            prefix = "User" if msg.role == "user" else "Assistant"
            history_text += f"{prefix}: {msg.content}\n"

    prompt = f"Answer using ONLY the context below.\n\nContext:\n{context_text}\n"
    if history_text:
        prompt += f"\nConversation so far:\n{history_text}"
    prompt += f"\nUser: {request.question}\nAssistant:"

    response = requests.post(
        OLLAMA_CHAT,
        json={"model": request.model, "prompt": prompt, "stream": False}
    )
    chat_data = response.json()
    if "error" in chat_data:
        raise HTTPException(status_code=500, detail=f"Ollama error: {chat_data['error']}")

    return {
        "answer": chat_data["response"],
        "sources": sources,
        "context": context_text
    }
