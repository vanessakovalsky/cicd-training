"""API HTTP de FretExpress."""

import os
from decimal import Decimal
from functools import lru_cache
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, status
from pydantic import BaseModel, Field

from fretexpress import __version__
from fretexpress.carburant import FournisseurCarburantFixe, FournisseurCarburantHttp
from fretexpress.devis import DepotDevis
from fretexpress.tarification import CalculateurTarif

app = FastAPI(title="FretExpress", version=__version__)


class DemandeDevis(BaseModel):
    poids_kg: Decimal = Field(gt=0, le=30)
    zone: str
    express: bool = False
    code_remise: str | None = None


class ReponseDevis(BaseModel):
    numero: str
    montant: Decimal


@lru_cache
def get_depot() -> DepotDevis:
    return DepotDevis(os.environ.get("FRETEXPRESS_DB", "fretexpress.db"))


@lru_cache
def get_calculateur() -> CalculateurTarif:
    url = os.environ.get("FRETEXPRESS_CARBURANT_URL")
    fournisseur = FournisseurCarburantHttp(url) if url else FournisseurCarburantFixe()
    return CalculateurTarif(fournisseur)


@app.get("/health")
def health() -> dict[str, str]:
    """Sonde de vie utilisee par les tests de fumee et Traefik."""
    return {"statut": "ok"}


@app.get("/version")
def get_version() -> dict[str, str]:
    """Version deployee (utile pour verifier une promotion)."""
    return {"version": __version__}


@app.post("/devis", status_code=status.HTTP_201_CREATED, response_model=ReponseDevis)
def creer_devis(
    demande: DemandeDevis,
    depot: Annotated[DepotDevis, Depends(get_depot)],
    calculateur: Annotated[CalculateurTarif, Depends(get_calculateur)],
) -> ReponseDevis:
    try:
        montant = calculateur.tarif_final(
            demande.poids_kg, demande.zone, demande.express, demande.code_remise
        )
    except ValueError as erreur:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(erreur)) from erreur
    devis = depot.enregistrer(
        demande.poids_kg, demande.zone, montant, demande.express, demande.code_remise
    )
    return ReponseDevis(numero=devis.numero, montant=devis.montant)


@app.get("/devis/{numero}", response_model=ReponseDevis)
def lire_devis(numero: str, depot: Annotated[DepotDevis, Depends(get_depot)]) -> ReponseDevis:
    devis = depot.trouver(numero)
    if devis is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, f"Devis {numero} introuvable")
    return ReponseDevis(numero=devis.numero, montant=devis.montant)
