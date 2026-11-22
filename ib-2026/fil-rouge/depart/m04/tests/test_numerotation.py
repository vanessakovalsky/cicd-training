from fretexpress.devis import prochain_numero


def test_premier_devis_numerote_d0001():
    assert prochain_numero() == "D-0001"


def test_deuxieme_devis_numerote_d0002():
    assert prochain_numero() == "D-0002"


def test_format_du_numero():
    numero = prochain_numero()

    assert numero.startswith("D-")
    assert len(numero) == 6
