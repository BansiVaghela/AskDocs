from pypdf import PdfReader
import chromadb
import requests
import os

client = chromadb.PersistentClient(path="./chroma_db")
collection = client.get_or_create_collection(name="documents", embedding_functions=None)

OLLAMA_URL = "http://localhost:11434/api/embeddings"


def get_embedding(text):
    response = requests.post(
        OLLAMA_URL,
        json={"model": "nomic-embed-text", "prompt": text}
    )
    data = response.json()
    if "error" in data:
        raise RuntimeError(f"Embedding error: {data['error']}")
    return data["embedding"]


def process_pdf(filepath):
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


pdf_dir = "./policies"
for file in os.listdir(pdf_dir):
    if file.endswith(".pdf"):
        process_pdf(os.path.join(pdf_dir, file))
