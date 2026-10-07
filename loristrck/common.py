"""Deprecated compat shim. Use loristrck.util.db2amp instead."""

from .util import db2amp as db2amp
from .util import db2ampnp as db2ampnp

__all__ = ["db2amp", "db2ampnp"]
