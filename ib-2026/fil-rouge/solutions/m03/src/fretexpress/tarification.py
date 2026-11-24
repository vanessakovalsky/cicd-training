"""Moteur de tarification FretExpress (developpe en TDD, module 03)."""

from decimal import ROUND_HALF_UP, Decimal
from math import ceil
from typing import Protocol

PRIX_BASE = Decimal("5.00")  # jusqu'a 1 kg inclus
PRIX_KG_SUPPLEMENTAIRE = Decimal("1.50")  # par kg entame au-dela de 1 kg
POIDS_MAX_KG = Decimal("30")
MAJORATION_EXPRESS = Decimal("1.40")
COEFFICIENTS_ZONE = {
    "FR": Decimal("1.0"),
    "UE": Decimal("1.5"),
    "MONDE": Decimal("2.5"),
}
REMISES = {"FIDELE10": Decimal("0.10")}
TAUX_CARBURANT_MAX = Decimal("0.20")


class PoidsInvalide(ValueError):
    """Poids nul, negatif ou superieur a 30 kg."""


class ZoneInconnue(ValueError):
    """Zone absente de la grille tarifaire."""


class CodeRemiseInconnu(ValueError):
    """Code de remise non reconnu."""


class FournisseurCarburant(Protocol):
    """Dependance externe : taux de surcharge carburant (ex. Decimal("0.12"))."""

    def taux_actuel(self) -> Decimal: ...


def _arrondir(montant: Decimal) -> Decimal:
    return montant.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def calculer_tarif(
    poids_kg: Decimal | float | int,
    zone: str,
    express: bool = False,
    code_remise: str | None = None,
) -> Decimal:
    """Tarif HT d'un colis, hors surcharge carburant."""
    poids = Decimal(str(poids_kg))
    if poids <= 0 or poids > POIDS_MAX_KG:
        raise PoidsInvalide(f"Poids hors limites : {poids} kg (0 < poids <= 30)")
    if zone not in COEFFICIENTS_ZONE:
        raise ZoneInconnue(f"Zone inconnue : {zone}")

    kg_supplementaires = max(0, ceil(poids - 1))
    tarif = PRIX_BASE + PRIX_KG_SUPPLEMENTAIRE * kg_supplementaires
    tarif *= COEFFICIENTS_ZONE[zone]
    if express:
        tarif *= MAJORATION_EXPRESS
    if code_remise is not None:
        if code_remise not in REMISES:
            raise CodeRemiseInconnu(f"Code de remise inconnu : {code_remise}")
        tarif *= 1 - REMISES[code_remise]
    return _arrondir(tarif)


class CalculateurTarif:
    """Tarif final = tarif de base + surcharge carburant (taux plafonne a 20 %)."""

    def __init__(self, fournisseur_carburant: FournisseurCarburant) -> None:
        self._fournisseur = fournisseur_carburant

    def tarif_final(
        self,
        poids_kg: Decimal | float | int,
        zone: str,
        express: bool = False,
        code_remise: str | None = None,
    ) -> Decimal:
        base = calculer_tarif(poids_kg, zone, express, code_remise)
        taux = min(self._fournisseur.taux_actuel(), TAUX_CARBURANT_MAX)
        return _arrondir(base * (1 + taux))
