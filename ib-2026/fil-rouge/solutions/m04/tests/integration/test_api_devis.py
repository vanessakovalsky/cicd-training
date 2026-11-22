def test_creer_un_devis_renvoie_201_et_le_montant(client):
    reponse = client.post("/devis", json={"poids_kg": 1, "zone": "FR"})

    assert reponse.status_code == 201
    assert reponse.json() == {"numero": "D-0001", "montant": "5.50"}


def test_relire_un_devis_cree(client):
    numero = client.post("/devis", json={"poids_kg": 2, "zone": "UE"}).json()["numero"]

    reponse = client.get(f"/devis/{numero}")

    assert reponse.status_code == 200
    assert reponse.json()["montant"] == "10.73"


def test_devis_inconnu_renvoie_404(client):
    assert client.get("/devis/D-9999").status_code == 404


def test_zone_inconnue_renvoie_422(client):
    reponse = client.post("/devis", json={"poids_kg": 1, "zone": "LUNE"})

    assert reponse.status_code == 422
    assert "Zone inconnue" in reponse.json()["detail"]


def test_poids_hors_limites_rejete_par_la_validation(client):
    assert client.post("/devis", json={"poids_kg": 31, "zone": "FR"}).status_code == 422
