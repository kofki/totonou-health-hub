from fastapi import FastAPI

app = FastAPI(title="Health Hub ML Service")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


# TODO: P3-01 / P3-02 (OWNER) — add your model endpoints here once you build them in models/.
# The request/response contract with the Spring API is yours to design (P2-03 pattern applies).
