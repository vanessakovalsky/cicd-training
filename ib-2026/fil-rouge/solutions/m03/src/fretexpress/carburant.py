"""Fournisseurs du taux de surcharge carburant."""

import logging
from decimal import Decimal

import httpx

TAUX_PAR_DEFAUT = Decimal("0.15")
journal = logging.getLogger(__name__)


class FournisseurCarburantHttp:
    """Implementation reelle : interroge le service carburant (GET <url>/taux)."""

    def __init__(self, url: str, client: httpx.Client | None = None, timeout: float = 2.0) -> None:
        self._url = url.rstrip("/")
        self._client = client or httpx.Client(timeout=timeout)

    def taux_actuel(self) -> Decimal:
        try:
            reponse = self._client.get(f"{self._url}/taux")
            reponse.raise_for_status()
            return Decimal(str(reponse.json()["taux"]))
        except (httpx.HTTPError, KeyError, ValueError) as erreur:
            journal.warning("Service carburant indisponible (%s) : taux par defaut", erreur)
            return TAUX_PAR_DEFAUT


class FournisseurCarburantFixe:
    """Fake : taux constant, utilisable en test et en environnement sans service carburant."""

    def __init__(self, taux: Decimal = TAUX_PAR_DEFAUT) -> None:
        self._taux = taux

    def taux_actuel(self) -> Decimal:
        return self._taux
