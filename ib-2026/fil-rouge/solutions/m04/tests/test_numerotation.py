import re

import pytest

from fretexpress.devis import Numeroteur


@pytest.fixture
def numeroteur():
    return Numeroteur()  # instance neuve a chaque test : aucun etat partage


def test_premier_devis_numerote_d0001(numeroteur):
    assert numeroteur.prochain_numero() == "D-0001"


def test_deuxieme_devis_numerote_d0002(numeroteur):
    numeroteur.prochain_numero()

    assert numeroteur.prochain_numero() == "D-0002"


def test_format_du_numero(numeroteur):
    assert re.fullmatch(r"D-\d{4}", numeroteur.prochain_numero())
