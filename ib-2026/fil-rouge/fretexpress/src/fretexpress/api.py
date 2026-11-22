"""API HTTP de FretExpress."""

from fastapi import FastAPI

from fretexpress import __version__

app = FastAPI(title="FretExpress", version=__version__)


@app.get("/health")
def health() -> dict[str, str]:
    """Sonde de vie utilisee par les tests de fumee et Traefik."""
    return {"statut": "ok"}


@app.get("/version")
def get_version() -> dict[str, str]:
    """Version deployee (utile pour verifier une promotion)."""
    return {"version": __version__}
