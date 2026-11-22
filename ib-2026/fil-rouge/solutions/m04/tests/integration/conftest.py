from decimal import Decimal

import pytest
from fastapi.testclient import TestClient

from fretexpress.api import app, get_calculateur, get_depot
from fretexpress.carburant import FournisseurCarburantFixe
from fretexpress.devis import DepotDevis
from fretexpress.tarification import CalculateurTarif


def pytest_collection_modifyitems(items):
    for item in items:
        if "/integration/" in str(item.fspath):
            item.add_marker(pytest.mark.integration)


@pytest.fixture
def depot(tmp_path):
    return DepotDevis(str(tmp_path / "test.db"))  # base neuve par test


@pytest.fixture
def client(depot):
    app.dependency_overrides[get_depot] = lambda: depot
    app.dependency_overrides[get_calculateur] = lambda: CalculateurTarif(
        FournisseurCarburantFixe(Decimal("0.10"))
    )
    yield TestClient(app)
    app.dependency_overrides.clear()
