from typing import Any, Optional
import numpy as np



import logging
logger: logging.Logger

class PartialListW:
    @classmethod
    def __init__(cls, *args, **kwargs) -> None: ...
    def dump(self) -> Any: ...
    def setlabels(self, labels: list[int]) -> None: ...
    def toarray(self) -> list[np.ndarray]: ...
    def __len__(self) -> int: ...
    def __reduce__(self) -> Any: ...
    def __setstate__(self, state) -> Any: ...

def __pyx_unpickle_Enum(*args, **kwargs) -> Any: ...
def _isiterable(seq) -> Any: ...
def _make_rbep_frame(*args, **kwargs) -> Any: ...
def _write_sdif(partials, outfile, labels = ..., rbep = ...) -> Any: ...

def analyze(samples: np.ndarray,
            sr: float,
            resolution: float,
            windowsize: float = -1,
            hoptime: float = -1,
            freqrift: float = -1,
            sidelobe: float = -1,
            ampfloor: float = -90,
            croptime: float = -1,
            residuebw: float = 1,
            convergencebw: float = -1,
            outfile: str = None
            ) -> list[np.ndarray]: ...

def estimatef0(partials: list[np.ndarray],
               minfreq: float,
               maxfreq: float,
               interval: float
               ) -> tuple[np.ndarray, np.ndarray, float, float]: ...

def kaiserWindowLength(width: float,
                       sr: float,
                       sidelobe: float
                       ) -> int: ...

def meancol(X: np.ndarray, col: int) -> float: ...
def meancolw(X: np.ndarray, col: int, colw: int) -> float: ...
def newPartialList(partials: list[np.ndarray], labels: Optional[list[int]] = None
                   ) -> PartialListW: ...
def read_aiff(path: str) -> tuple[np.ndarray, int]: ...
def read_sdif(path: str) -> tuple[list[np.ndarray], list[int]]: ...
def synthesize(partials: list[np.ndarray],
               samplerate: int,
               fadetime: float = -1,
               start: float = -1,
               end: float = -1
               ) -> np.ndarray: ...
