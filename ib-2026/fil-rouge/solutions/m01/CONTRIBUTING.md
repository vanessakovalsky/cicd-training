# Contribuer a FretExpress

## Strategie de branches : GitHub Flow

- `main` : toujours deployable, protegee (aucun push direct).
- Une branche courte par changement, creee depuis `main` :
  `feat/<sujet>`, `fix/<sujet>`, `docs/<sujet>`, `ci/<sujet>`, `test/<sujet>`.
- Integration par merge request uniquement, apres :
  - 1 approbation d'un relecteur ;
  - pipeline CI au vert (a partir du module 05).
- Branche supprimee apres fusion. Duree de vie cible : moins de 2 jours.

## Messages de commit : Conventional Commits

    <type>(<portee optionnelle>): <resume a l'imperatif, 72 caracteres max>

Types : `feat`, `fix`, `test`, `refactor`, `docs`, `ci`, `chore`.

Exemples :
- `feat(tarif): ajouter la majoration express`
- `test(tarif): couvrir le poids maximal de 30 kg`

## Revue de code

- Relecteur : comprend le changement, verifie tests et lisibilite, commente avec
  des suggestions concretes.
- Auteur : repond a chaque commentaire, pousse les corrections sur la meme branche.
