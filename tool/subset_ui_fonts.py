"""Rebuild the two small UI fallback fonts (development-only fontTools)."""
from hashlib import sha256
from pathlib import Path
from tempfile import TemporaryDirectory
from urllib.request import urlretrieve

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parent.parent
SOURCES = [
    (
        'Emoji',
        'https://raw.githubusercontent.com/googlefonts/noto-emoji/'
        'f3ae03f5e9b3b8516fa151f7168159ca1a3e7515/fonts/Noto-COLRv1.ttf',
        '0ae57fe58645638523ba35f388d93739d292539a9acb84df5700c81b1e1a28d2',
    ),
    (
        'Symbols',
        'https://fonts.gstatic.com/s/notosanssymbols2/v24/'
        'I_uyMoGduATTei9eI8daxVHDyfisHr71-vrgfE71.woff2',
        'c90fbe98152bbb119a7e521a048c6aa6fc367879d6e3dae6db5a17582de25ead',
    ),
]

with TemporaryDirectory() as temp:
    for kind, url, expected_hash in SOURCES:
        source = Path(temp) / kind
        urlretrieve(url, source)
        if sha256(source.read_bytes()).hexdigest() != expected_hash:
            raise ValueError(f'{kind}: upstream bytes changed; review before updating')
        font = TTFont(source, recalcTimestamp=False)
        codepoints = (ROOT / f'docs/fonts/{kind.lower()}-codepoints.txt').read_text()
        runes = [int(value.strip().removeprefix('U+'), 16)
                 for value in codepoints.strip().split(',')]
        if not set(runes) <= set(font.getBestCmap()):
            raise ValueError(f'{kind}: source does not cover every requested code point')
        options = subset.Options()
        options.name_IDs = ['*']
        options.name_legacy = True
        options.name_languages = ['*']
        subsetter = subset.Subsetter(options=options)
        subsetter.populate(unicodes=runes)
        subsetter.subset(font)
        font.flavor = None  # Export TTF, including from the WOFF2 source.
        for record in font['name'].names:
            if record.nameID in (1, 4, 6, 16):
                family = f'Everglow{kind}' if record.nameID == 6 else f'Everglow {kind}'
                record.string = family.encode(record.getEncoding())
        output = ROOT / f'assets/google_fonts/Everglow{kind}.ttf'
        font.save(output)
        print(f'{kind}: {len(runes)} code points, {output.stat().st_size} bytes')
