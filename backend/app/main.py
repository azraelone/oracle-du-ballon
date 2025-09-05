from fastapi import FastAPI

app = FastAPI(title="Oracle du Ballon API")

@app.get("/health")
def health():
    return {"status": "ok"}
