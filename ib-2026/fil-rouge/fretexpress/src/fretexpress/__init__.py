"""FretExpress - calcul de tarifs d'expedition."""

from importlib.metadata import PackageNotFoundError, version

try:
    __version__ = version("fretexpress")
except PackageNotFoundError:  # paquet non installe (execution depuis les sources)
    __version__ = "0.0.0"
