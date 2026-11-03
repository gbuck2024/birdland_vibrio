#!/usr/bin/env python3
"""Small synthetic checks; safe to run on a login node."""

import gzip
import tempfile
import unittest
from pathlib import Path

from reyranella_kmer_validation import K, build_markers, count_pair_files, kmers


def reverse_complement(seq):
    return seq.translate(bytes.maketrans(b"ACGT", b"TGCA"))[::-1]


def fastq(path, entries):
    with gzip.open(path, "wb") as handle:
        for name, seq in entries:
            handle.write(b"@" + name + b"\n" + seq + b"\n+\n" + b"I" * len(seq) + b"\n")


class KmerTests(unittest.TestCase):
    def test_reverse_complement_and_ambiguity(self):
        seq = b"ACGTTGCATGGCTACTAGGATCCTAGCTTACGAA"
        forward = list(kmers(seq))
        reverse = list(kmers(reverse_complement(seq)))
        self.assertEqual(forward, list(reversed(reverse)))
        self.assertEqual(len(list(kmers(seq + b"N" + seq))), 2 * (len(seq) - K + 1))

    def test_exclusive_shared_and_pair_deduplication(self):
        a = b"ACGTTGCATGGCTACTAGGATCCTAGCTTACGAA"
        b = b"TTTTGGCAGCTAGCTTACCGATACCGTATGACCA"
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            reference = root / "ref.fa"
            reference.write_bytes(b">a\n" + a + b"\n>b\n" + b + b"\n>other\n" + b + b"\n")
            exclusive, owners, shared_other, catalog = build_markers(reference, ["a", "b"])
            self.assertTrue(exclusive)
            self.assertEqual(catalog[("b", "exclusive")], 0)
            self.assertGreater(catalog[("b", "shared_other")], 0)
            self.assertTrue(shared_other)
            self.assertEqual(len(owners), len(set(kmers(a)) | set(kmers(b))))
            r1, r2 = root / "r1.fq.gz", root / "r2.fq.gz"
            fastq(r1, [(b"pair/1", reverse_complement(a))])
            fastq(r2, [(b"pair/2", a + a)])
            occurrences, observed, pairs, totals = count_pair_files(r1, r2, exclusive, 1)
            self.assertEqual(pairs[0], 1)
            self.assertGreater(occurrences[0], len(observed[0]))
            self.assertEqual(totals["read_pairs"], 1)
            self.assertEqual(pairs[1], 0)
            fastq(r1, [(b"negative/1", b"T" * 40)])
            fastq(r2, [(b"negative/2", b"T" * 40)])
            negative_occ, negative_seen, negative_pairs, _ = count_pair_files(r1, r2, exclusive, 1)
            self.assertFalse(negative_occ)
            self.assertFalse(negative_seen)
            self.assertFalse(negative_pairs)

    def test_mismatched_names_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            r1, r2 = Path(temp) / "r1.fq.gz", Path(temp) / "r2.fq.gz"
            fastq(r1, [(b"one", b"A" * 31)])
            fastq(r2, [(b"two", b"A" * 31)])
            with self.assertRaisesRegex(ValueError, "out of sync"):
                count_pair_files(r1, r2, {}, 1)

    def test_shared_across_candidates_is_not_exclusive(self):
        seq = b"ACGTTGCATGGCTACTAGGATCCTAGCTTACGAA"
        with tempfile.TemporaryDirectory() as temp:
            reference = Path(temp) / "ref.fa"
            reference.write_bytes(b">a\n" + seq + b"\n>b\n" + seq + b"\n")
            exclusive, owners, _, catalog = build_markers(reference, ["a", "b"])
            self.assertFalse(exclusive)
            self.assertEqual(catalog[("a", "shared_candidates")], len(owners))
            self.assertEqual(catalog[("b", "shared_candidates")], len(owners))


if __name__ == "__main__":
    unittest.main()
