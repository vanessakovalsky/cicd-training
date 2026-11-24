from decimal import Decimal
from unittest.mock import Mock

import httpx

from fretexpress.carburant import (
    TAUX_PAR_DEFAUT,
    FournisseurCarburantFixe,
    FournisseurCarburantHttp,
)
from fretexpress.tarification import CalculateurTarif


class StubCarburant:
    """Stub : reponse preprogrammee, aucune verification d'appel."""

    def __init__(self, taux: str) -> None:
        self.taux = Decimal(taux)

    def taux_actuel(self) -> Decimal:
        return self.taux


def test_surcharge_carburant_appliquee_au_tarif_de_base():
    calculateur = CalculateurTarif(StubCarburant("0.10"))

    assert calculateur.tarif_final(1, "FR") == Decimal("5.50")


def test_taux_carburant_plafonne_a_20_pourcent():
    calculateur = CalculateurTarif(StubCarburant("0.35"))

    assert calculateur.tarif_final(1, "FR") == Decimal("6.00")


def test_fake_taux_fixe_par_defaut():
    calculateur = CalculateurTarif(FournisseurCarburantFixe())

    assert calculateur.tarif_final(1, "FR") == Decimal("5.75")


def test_le_fournisseur_est_interroge_une_seule_fois_par_calcul():
    mock = Mock()
    mock.taux_actuel.return_value = Decimal("0")

    CalculateurTarif(mock).tarif_final(1, "FR")

    mock.taux_actuel.assert_called_once_with()


def _client_http(gestionnaire) -> httpx.Client:
    return httpx.Client(transport=httpx.MockTransport(gestionnaire))


def test_fournisseur_http_lit_le_taux_du_service():
    client = _client_http(lambda requete: httpx.Response(200, json={"taux": "0.12"}))

    fournisseur = FournisseurCarburantHttp("http://carburant", client=client)

    assert fournisseur.taux_actuel() == Decimal("0.12")


def test_fournisseur_http_bascule_sur_le_taux_par_defaut_si_service_en_erreur():
    client = _client_http(lambda requete: httpx.Response(503))

    fournisseur = FournisseurCarburantHttp("http://carburant", client=client)

    assert fournisseur.taux_actuel() == TAUX_PAR_DEFAUT
