"""Devis d'expedition et depot SQLite (module 04)."""

import sqlite3
from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal


class Numeroteur:
    """Numerotation par instance : aucun etat global partage entre les tests."""

    def __init__(self, depart: int = 0) -> None:
        self._compteur = depart

    def prochain_numero(self) -> str:
        self._compteur += 1
        return f"D-{self._compteur:04d}"


@dataclass
class Devis:
    numero: str
    poids_kg: Decimal
    zone: str
    montant: Decimal
    express: bool = False
    code_remise: str | None = None
    cree_le: datetime = field(default_factory=lambda: datetime.now(UTC))


class DepotDevis:
    """Persistance des devis dans SQLite (fichier ou ':memory:')."""

    def __init__(self, chemin_db: str) -> None:
        self._connexion = sqlite3.connect(chemin_db, check_same_thread=False)
        self._connexion.execute(
            """CREATE TABLE IF NOT EXISTS devis (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                numero TEXT UNIQUE,
                poids_kg TEXT NOT NULL,
                zone TEXT NOT NULL,
                express INTEGER NOT NULL,
                code_remise TEXT,
                montant TEXT NOT NULL,
                cree_le TEXT NOT NULL
            )"""
        )
        self._connexion.commit()

    def enregistrer(
        self,
        poids_kg: Decimal,
        zone: str,
        montant: Decimal,
        express: bool = False,
        code_remise: str | None = None,
    ) -> Devis:
        cree_le = datetime.now(UTC)
        curseur = self._connexion.execute(
            "INSERT INTO devis (poids_kg, zone, express, code_remise, montant, cree_le) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (str(poids_kg), zone, int(express), code_remise, str(montant), cree_le.isoformat()),
        )
        numero = f"D-{curseur.lastrowid:04d}"
        self._connexion.execute(
            "UPDATE devis SET numero = ? WHERE id = ?", (numero, curseur.lastrowid)
        )
        self._connexion.commit()
        return Devis(numero, Decimal(str(poids_kg)), zone, montant, express, code_remise, cree_le)

    def trouver(self, numero: str) -> Devis | None:
        ligne = self._connexion.execute(
            "SELECT numero, poids_kg, zone, montant, express, code_remise, cree_le "
            "FROM devis WHERE numero = ?",
            (numero,),
        ).fetchone()
        if ligne is None:
            return None
        return Devis(
            numero=ligne[0],
            poids_kg=Decimal(ligne[1]),
            zone=ligne[2],
            montant=Decimal(ligne[3]),
            express=bool(ligne[4]),
            code_remise=ligne[5],
            cree_le=datetime.fromisoformat(ligne[6]),
        )
