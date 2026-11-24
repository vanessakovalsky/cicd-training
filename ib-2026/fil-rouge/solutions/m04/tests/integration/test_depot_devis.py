from decimal import Decimal


def test_enregistrer_puis_trouver_un_devis(depot):
    cree = depot.enregistrer(Decimal("2"), "UE", Decimal("9.75"), express=False)

    relu = depot.trouver(cree.numero)

    assert relu is not None
    assert relu.numero == "D-0001"
    assert relu.montant == Decimal("9.75")
    assert relu.zone == "UE"


def test_numeros_sequentiels(depot):
    premier = depot.enregistrer(Decimal("1"), "FR", Decimal("5.00"))
    second = depot.enregistrer(Decimal("1"), "FR", Decimal("5.00"))

    assert (premier.numero, second.numero) == ("D-0001", "D-0002")


def test_devis_inexistant(depot):
    assert depot.trouver("D-9999") is None
