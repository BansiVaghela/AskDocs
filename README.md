# RAG Demo

A local Retrieval-Augmented Generation (RAG) app — upload PDFs and ask questions answered strictly from your documents.

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

### 3. Add your PDFs
Drop PDF files into `Backend/policies/`, then run:
```bash
python ingest.py
```

### 4. Start the server
```bash
uvicorn app:app --reload
```

### 5. iOS App
Open `RAG_Demo_UI/RAG_Demo_UI.xcodeproj` in Xcode and run on the simulator.

## API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| POST | `/ask` | Ask a question |
| GET | `/documents` | List uploaded PDFs |
| POST | `/upload` | Upload and ingest a PDF |
| DELETE | `/documents/{filename}` | Delete a document |
| GET | `/models` | List available Ollama models |

## Notes

- `chroma_db/` and `policies/` are excluded from git — rebuild locally using `ingest.py`
- All AI runs locally — no data leaves your machine
