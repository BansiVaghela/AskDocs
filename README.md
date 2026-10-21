# AskDocs

A local Retrieval-Augmented Generation (RAG) app — upload PDFs from your iPhone and ask questions answered strictly from your documents.

## Stack

| Layer | Technology |
|---|---|
| iOS App | SwiftUI |
| Backend | FastAPI (Python) |
| Vector DB | ChromaDB |
| Embedding Model | nomic-embed-text (via Ollama) |
| LLM | llama3.2 (via Ollama) |

## Architecture

```
iOS App ──HTTP──▶ FastAPI Backend ──▶ Ollama
                        │
                        ▼
                   ChromaDB (local)
```

## Prerequisites

- [Ollama](https://ollama.com) installed and running
- Python 3.10+
- Xcode 14+

## Setup

### 1. Pull AI models
```bash
ollama pull nomic-embed-text
ollama pull llama3.2
```

### 2. Backend
```bash
cd Backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Start the server
```bash
uvicorn app:app --reload
```

### 4. iOS App
Open `RAG_Demo_UI/RAG_Demo_UI.xcodeproj` in Xcode and run on the simulator.

### 5. Upload PDFs
Use the **Documents** tab in the app to upload PDFs directly. The backend will ingest them automatically.

> **Simulator note:** Drag your PDF into the Simulator's Files app first, then use the upload button in AskDocs.

## Bulk Ingest (Optional)

If you want to pre-load PDFs without the app, drop them into `Backend/policies/` and run:
```bash
python ingest.py
```

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/ask` | Ask a question |
| GET | `/documents` | List uploaded PDFs |
| POST | `/upload` | Upload and ingest a PDF |
| DELETE | `/documents/{filename}` | Delete a document |
| GET | `/models` | List available Ollama models |

## Notes

- `chroma_db/` and `policies/` are excluded from git — they are rebuilt when you upload documents via the app
- All AI runs locally — no data leaves your machine
