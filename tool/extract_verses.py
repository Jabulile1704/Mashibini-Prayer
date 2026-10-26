"""Pulls a curated set of verses out of the WEBPB verse-per-line file.

Run with the VPL path and the output path as arguments. Kept outside the
download directory on purpose: nothing here imports from beside the archive.
"""
import io, json, sys

VPL, OUT = sys.argv[1], sys.argv[2]

# Chosen for a family that prays together: trust, thanksgiving, asking,
# steadiness, and a few about being a household. Deliberately short verses —
# a long one does not read well on a phone at a glance.
WANTED = [
    ("NUM 6:24", "Numbers 6:24"), ("NUM 6:25", "Numbers 6:25"),
    ("NUM 6:26", "Numbers 6:26"),
    ("DEU 6:6", "Deuteronomy 6:6"), ("DEU 31:6", "Deuteronomy 31:6"),
    ("JOS 1:9", "Joshua 1:9"), ("JOS 24:15", "Joshua 24:15"),
    ("PSA 19:14", "Psalm 19:14"), ("PSA 23:1", "Psalm 23:1"),
    ("PSA 27:1", "Psalm 27:1"), ("PSA 34:18", "Psalm 34:18"),
    ("PSA 37:4", "Psalm 37:4"), ("PSA 46:7", "Psalm 46:7"),
    ("PSA 46:10", "Psalm 46:10"), ("PSA 51:10", "Psalm 51:10"),
    ("PSA 55:22", "Psalm 55:22"), ("PSA 62:8", "Psalm 62:8"),
    ("PSA 90:12", "Psalm 90:12"), ("PSA 103:2", "Psalm 103:2"),
    ("PSA 118:24", "Psalm 118:24"), ("PSA 121:1", "Psalm 121:1"),
    ("PSA 121:2", "Psalm 121:2"), ("PSA 127:1", "Psalm 127:1"),
    ("PSA 133:1", "Psalm 133:1"), ("PSA 136:1", "Psalm 136:1"),
    ("PSA 139:14", "Psalm 139:14"), ("PSA 145:18", "Psalm 145:18"),
    ("PRO 3:5", "Proverbs 3:5"), ("PRO 3:6", "Proverbs 3:6"),
    ("PRO 17:17", "Proverbs 17:17"), ("PRO 18:10", "Proverbs 18:10"),
    ("PRO 22:6", "Proverbs 22:6"),
    ("ISA 26:3", "Isaiah 26:3"), ("ISA 40:29", "Isaiah 40:29"),
    ("ISA 41:10", "Isaiah 41:10"), ("ISA 43:2", "Isaiah 43:2"),
    ("JER 29:11", "Jeremiah 29:11"), ("JER 33:3", "Jeremiah 33:3"),
    ("LAM 3:22", "Lamentations 3:22"), ("LAM 3:23", "Lamentations 3:23"),
    ("MIC 6:8", "Micah 6:8"), ("ZEP 3:17", "Zephaniah 3:17"),
    ("MAT 6:33", "Matthew 6:33"), ("MAT 11:28", "Matthew 11:28"),
    ("MAT 18:20", "Matthew 18:20"), ("MAR 11:24", "Mark 11:24"),
    ("LUK 11:9", "Luke 11:9"), ("JOH 3:16", "John 3:16"),
    ("JOH 14:27", "John 14:27"), ("JOH 15:12", "John 15:12"),
    ("ACT 2:42", "Acts 2:42"),
    ("ROM 5:8", "Romans 5:8"), ("ROM 8:28", "Romans 8:28"),
    ("ROM 12:2", "Romans 12:2"), ("ROM 15:13", "Romans 15:13"),
    ("1CO 13:4", "1 Corinthians 13:4"), ("1CO 13:13", "1 Corinthians 13:13"),
    ("2CO 12:9", "2 Corinthians 12:9"),
    ("EPH 4:32", "Ephesians 4:32"), ("EPH 6:10", "Ephesians 6:10"),
    ("PHI 4:6", "Philippians 4:6"), ("PHI 4:7", "Philippians 4:7"),
    ("PHI 4:13", "Philippians 4:13"), ("PHI 4:19", "Philippians 4:19"),
    ("COL 3:17", "Colossians 3:17"),
    ("1TH 5:16", "1 Thessalonians 5:16"),
    ("1TH 5:17", "1 Thessalonians 5:17"),
    ("1TH 5:18", "1 Thessalonians 5:18"),
    ("HEB 10:24", "Hebrews 10:24"), ("HEB 11:1", "Hebrews 11:1"),
    ("HEB 13:8", "Hebrews 13:8"),
    ("JAM 1:5", "James 1:5"), ("JAM 5:16", "James 5:16"),
    ("1PE 5:6", "1 Peter 5:6"), ("1JO 4:19", "1 John 4:19"),
]

found, missing = {}, []
for line in io.open(VPL, encoding='utf-8'):
    key = ' '.join(line.split(' ', 2)[:2])
    found[key] = line.split(' ', 2)[2].strip() if line.count(' ') >= 2 else ''

verses = []
for key, reference in WANTED:
    text = found.get(key)
    if not text:
        missing.append(key)
        continue
    # The text is taken exactly as published, including Psalm superscriptions
    # ("A Psalm by David.") and the quotation marks that belong to a longer
    # speech. Trimming them would read more neatly and would be a change to
    # the text — and the licence asks that anything changed not be called the
    # World English Bible any more. Accuracy of attribution beats tidiness.
    verses.append({'reference': reference, 'text': text})

payload = {
    'translation': {
        'name': 'World English Bible British Edition',
        'abbreviation': 'WEBPB',
        'edition': 'engwebpb, 2020 stable text',
        'licence': 'Public Domain',
        'source': 'https://eBible.org/Scriptures/engwebpb_vpl.zip',
        'retrieved': '2026-10-27',
        'notice': 'The World English Bible is in the Public Domain. '
                  '"World English Bible" is a trademark of eBible.org.',
    },
    'verses': verses,
}

io.open(OUT, 'w', encoding='utf-8').write(
    json.dumps(payload, ensure_ascii=False, indent=2) + '\n'
)
print(f'wrote {len(verses)} verses')
if missing:
    print('MISSING:', ', '.join(missing))
