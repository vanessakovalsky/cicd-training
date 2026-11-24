from decimal import Decimal

import pytest

from fretexpress.tarification import (
    CodeRemiseInconnu,
    PoidsInvalide,
    ZoneInconnue,
    calculer_tarif,
)


def test_colis_de_1_kg_en_france_coute_le_prix_de_base():
    assert calculer_tarif(1, "FR") == Decimal("5.00")


@pytest.mark.parametrize(
    ("poids", "attendu"),
    [
        (0.5, Decimal("5.00")),
        (1.2, Decimal("6.50")),  # 1 kg entame au-dela de 1 kg
        (2, Decimal("6.50")),
        (2.01, Decimal("8.00")),
        (30, Decimal("48.50")),
    ],
)
def test_chaque_kg_entame_au_dela_de_1_kg_coute_1_50(poids, attendu):
    assert calculer_tarif(poids, "FR") == attendu


@pytest.mark.parametrize(
    ("zone", "attendu"),
    [("FR", Decimal("5.00")), ("UE", Decimal("7.50")), ("MONDE", Decimal("12.50"))],
)
def test_coefficient_de_zone(zone, attendu):
    assert calculer_tarif(1, zone) == attendu


def test_option_express_majore_de_40_pourcent():
    assert calculer_tarif(1, "FR", express=True) == Decimal("7.00")


def test_remise_fidele10_retire_10_pourcent():
    assert calculer_tarif(1, "FR", code_remise="FIDELE10") == Decimal("4.50")


def test_regles_cumulees_avec_arrondi_au_centime():
    # (5 + 1.5 * 3) * 1.5 * 1.4 * 0.9 = 17.955 -> 17.96 (arrondi commercial)
    assert calculer_tarif(3.5, "UE", express=True, code_remise="FIDELE10") == Decimal("17.96")


@pytest.mark.parametrize("poids", [0, -1, 30.01])
def test_poids_hors_limites_refuse(poids):
    with pytest.raises(PoidsInvalide):
        calculer_tarif(poids, "FR")


def test_zone_inconnue_refusee():
    with pytest.raises(ZoneInconnue):
        calculer_tarif(1, "LUNE")


def test_code_remise_inconnu_refuse():
    with pytest.raises(CodeRemiseInconnu):
        calculer_tarif(1, "FR", code_remise="GRATUIT")
