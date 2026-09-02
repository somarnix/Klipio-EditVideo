"""Use packaged speech models without requiring a user cache or source drive."""
import os
import sys
import shutil
import uuid
from pathlib import Path

sys.dont_write_bytecode = True
root = Path(os.environ.get('LOCALAPPDATA', str(Path.home()))) / 'Klipio'
cache = root / 'Cache' / 'speech-models'
cache.mkdir(parents=True, exist_ok=True)
os.environ.setdefault('HF_HUB_CACHE', str(cache))
os.environ.setdefault('HF_HOME', str(root / 'Cache' / 'huggingface'))
bundled = Path(sys.executable).parent / 'models'
if bundled.is_dir():
    for source in bundled.iterdir():
        target = cache / source.name
        if not source.is_dir() or target.exists():
            continue
        staging = cache / ('.prepare-' + uuid.uuid4().hex)
        try:
            shutil.copytree(source, staging)
            try:
                staging.rename(target)
            except FileExistsError:
                pass  # Another isolated worker completed the same seed.
        finally:
            if staging.exists():
                shutil.rmtree(staging)
