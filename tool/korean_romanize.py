#!/usr/bin/env python3
"""Revised Romanization of Korean, with the sound-change rules that matter.

The Korean source file gives Hangul but no pronunciation. The app needs a
Roman reading under each Korean line, and the example in the brief -

    안녕하세요. 분위기가 정말 좋네요.
    Annyeonghaseyo. Bunwigiga jeongmal jonneyo.

- shows two things a naive syllable-by-syllable transliteration gets wrong:

  * "좋네요" becomes "jonneyo", not "johneyo". The batchim ㅎ before ㄴ
    assimilates to ㄴ (ㅎ+ㄴ -> ㄴ+ㄴ).
  * a trailing consonant links onto a following vowel: "분위기" is
    "bunwigi", the ㄴ of 분 carrying nothing unusual here, but the general
    rule (한국어 -> hangugeo) is that a batchim before an empty-onset syllable
    moves into that onset.

This implements Revised Romanization (the South Korean standard, and what the
brief's example uses) with the consonant-assimilation and liaison rules that
change the *sound*. It is not a full phonological engine - Korean has more
sandhi than any short table captures - so it also supports a hand-authored
override map for the handful of lines where the rules and the natural reading
disagree, and it reports which lines used one.

Romanization is generated once, at seed-build time, and stored on the line.
Nothing romanizes at runtime.
"""

# Jamo tables, indexed as Unicode composes them.
LEADS = ['g', 'kk', 'n', 'd', 'tt', 'r', 'm', 'b', 'pp', 's', 'ss', '',
         'j', 'jj', 'ch', 'k', 't', 'p', 'h']
VOWELS = ['a', 'ae', 'ya', 'yae', 'eo', 'e', 'yeo', 'ye', 'o', 'wa', 'wae',
          'oe', 'yo', 'u', 'wo', 'we', 'wi', 'yu', 'eu', 'ui', 'i']
# Final consonants, in their *released* Roman form before decomposition.
TAILS = ['', 'g', 'kk', 'gs', 'n', 'nj', 'nh', 'd', 'l', 'lg', 'lm', 'lb',
         'ls', 'lt', 'lp', 'lh', 'm', 'b', 'bs', 's', 'ss', 'ng', 'j', 'ch',
         'k', 't', 'p', 'h']

# The phonemic value of each final as it actually stops the syllable, used to
# decide assimilation. Korean neutralises finals to seven sounds.
TAIL_STOP = {
    '': '', 'g': 'k', 'kk': 'k', 'gs': 'k', 'n': 'n', 'nj': 'n', 'nh': 'n',
    'd': 't', 'l': 'l', 'lg': 'k', 'lm': 'm', 'lb': 'p', 'ls': 'l',
    'lt': 'l', 'lp': 'p', 'lh': 'l', 'm': 'm', 'b': 'p', 'bs': 'p',
    's': 't', 'ss': 't', 'ng': 'ng', 'j': 't', 'ch': 't', 'k': 'k',
    't': 't', 'p': 'p', 'h': 't',
}

SBASE, LCOUNT, VCOUNT, TCOUNT = 0xAC00, 19, 21, 28


def _decompose(char):
    """(lead index, vowel index, tail index) for a Hangul syllable, else None."""
    code = ord(char) - SBASE
    if code < 0 or code >= LCOUNT * VCOUNT * TCOUNT:
        return None
    lead = code // (VCOUNT * TCOUNT)
    vowel = (code % (VCOUNT * TCOUNT)) // TCOUNT
    tail = code % TCOUNT
    return lead, vowel, tail


def _apply_sandhi(syllables):
    """Adjusts syllables for the cross-syllable sound changes.

    Only the rules that change the Roman output and that appear in this data
    set are implemented: liaison of a batchim onto an empty onset, and the
    common assimilations (ㅎ+ㄴ, obstruent+nasal, ㄴ/ㄹ). Returns a list of
    (onset, vowel, coda) Roman strings ready to join.
    """
    n = len(syllables)
    # A consonant liaised from the previous syllable, waiting to be prepended
    # to this one's onset. Kept in its own list so a triple never has to hold
    # anything but its original integer indices.
    carried = [''] * n

    out = []
    for i, syl in enumerate(syllables):
        if syl is None:
            out.append(None)
            continue
        lead, vowel, tail = syl
        onset = carried[i] + LEADS[lead]
        coda = TAILS[tail]
        nxt = syllables[i + 1] if i + 1 < n else None

        if nxt is not None:
            n_onset = LEADS[nxt[0]]
            stop = TAIL_STOP[coda]

            # Liaison: a real batchim before an empty onset (ㅇ) moves across.
            if coda and n_onset == '':
                if coda == 'h':
                    # ㅎ is silent when it liaises: 좋아 -> jo-a.
                    coda = ''
                else:
                    carried[i + 1] = _LIAISON.get(coda, coda)
                    coda = ''

            # ㅎ batchim before a nasal: 좋네 -> jonne.
            elif stop == 't' and coda == 'h' and n_onset in ('n', 'm'):
                coda = n_onset

            # Obstruent + nasal: 학년 -> hangnyeon, 입니다 -> imnida.
            elif stop == 'k' and n_onset in ('n', 'm'):
                coda = 'ng'
            elif stop == 'p' and n_onset in ('n', 'm'):
                coda = 'm'
            elif stop == 't' and n_onset in ('n', 'm'):
                coda = 'n'

            # ㄴ+ㄹ / ㄹ+ㄴ -> ll: 신라 -> silla, 설날 -> seollal.
            elif stop == 'n' and n_onset == 'r':
                coda = 'l'
            elif stop == 'l' and n_onset == 'r':
                coda = 'l'
            else:
                coda = _RELEASE.get(coda, stop)
        else:
            coda = _RELEASE.get(coda, TAIL_STOP[coda])

        out.append((onset, VOWELS[vowel], coda))
    return out


# How a batchim sounds when it moves onto an empty onset (mostly itself, but
# some finals reveal a hidden consonant: 밖에 -> bakke).
_LIAISON = {
    'g': 'g', 'kk': 'kk', 'n': 'n', 'd': 'd', 'l': 'r', 'm': 'm', 'b': 'b',
    's': 's', 'ss': 'ss', 'ng': 'ng', 'j': 'j', 'ch': 'ch', 'k': 'k',
    't': 't', 'p': 'p', 'gs': 'ks', 'nj': 'nj', 'lg': 'lg', 'lm': 'lm',
    'lb': 'lb', 'bs': 'bs',
}

# Released Roman form of a final when nothing follows or a normal consonant
# does. Finals romanize by their stop value in most positions.
_RELEASE = {
    'g': 'k', 'kk': 'k', 'n': 'n', 'd': 't', 'l': 'l', 'm': 'm', 'b': 'p',
    's': 't', 'ss': 't', 'ng': 'ng', 'j': 't', 'ch': 't', 'k': 'k', 't': 't',
    'p': 'p', 'h': 't', 'gs': 'k', 'nj': 'n', 'nh': 'n', 'lg': 'k', 'lm': 'm',
    'lb': 'l', 'ls': 'l', 'lt': 'l', 'lp': 'p', 'lh': 'l', 'bs': 'p',
}


def romanize(text, overrides=None):
    """Romanizes a Korean string, applying an optional per-string override.

    Returns (romanization, used_override). Non-Hangul characters - spaces,
    punctuation, the 〇〇 placeholder - pass through unchanged.
    """
    overrides = overrides or {}
    if text in overrides:
        return overrides[text], True

    result = []
    run = []  # a run of consecutive Hangul syllables

    def flush():
        if not run:
            return ''
        triples = _apply_sandhi([_decompose(c) for c in run])
        # Resolve carried onsets from liaison.
        return ''.join(o + v + c for o, v, c in triples)

    for char in text:
        if _decompose(char) is not None:
            run.append(char)
        else:
            if run:
                result.append(flush())
                run = []
            result.append(char)
    if run:
        result.append(flush())

    roman = ''.join(result)
    roman = _capitalise_sentences(roman)
    return roman, False


def _capitalise_sentences(text):
    """Capitalises the first letter of each sentence, matching the brief's
    example ('Annyeonghaseyo. Bunwigiga ...')."""
    out = []
    capitalise = True
    for ch in text:
        if capitalise and ch.isalpha():
            out.append(ch.upper())
            capitalise = False
        else:
            out.append(ch)
        if ch in '.!?':
            capitalise = True
    return ''.join(out)


if __name__ == '__main__':
    import sys

    # Checks against known-correct readings, including the exact words from the
    # app's own example. A mismatch exits non-zero so CI fails on a regression.
    samples = [
        ('안녕하세요', 'Annyeonghaseyo'),
        ('좋네요', 'Jonneyo'),
        ('분위기가', 'Bunwigiga'),
        ('정말', 'Jeongmal'),
        ('한국어', 'Hangugeo'),
        ('안녕하세요. 분위기가 정말 좋네요.',
         'Annyeonghaseyo. Bunwigiga jeongmal jonneyo.'),
    ]
    failures = 0
    for hangul, expected in samples:
        got, _ = romanize(hangul)
        ok = got == expected
        failures += 0 if ok else 1
        print('%s %-24s -> %-40s %s'
              % ('OK ' if ok else 'XX ', hangul, got,
                 '' if ok else '(expected %s)' % expected))
    if failures:
        print('%d romanization check(s) failed.' % failures)
        sys.exit(1)
    print('All romanization checks passed.')
