#!/usr/bin/env python3
"""Synthetic interval tests for reference union and exactly-one coverage."""
import tempfile
import unittest
from pathlib import Path

from summarize_abrcms_reference_paf import summarize


class ReferenceCoverageTest(unittest.TestCase):
    def test_overlap_is_not_double_counted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            fasta = root / 'reference.fa'
            fasta.write_text('>chr1\n' + 'A' * 5000 + '\n')
            paf = root / 'alignments.paf'
            paf.write_text(
                'q1\t2000\t0\t2000\t+\tchr1\t5000\t0\t2000\t1990\t2000\t60\n'
                'q2\t2000\t0\t2000\t+\tchr1\t5000\t1000\t3000\t1980\t2000\t60\n'
                'q3\t1000\t0\t1000\t+\tchr1\t5000\t3000\t4000\t990\t1000\t0\n')
            result = summarize(fasta, paf)
            self.assertEqual(result['reference_bp'], 5000)
            self.assertEqual(result['retained_primary_alignments'], 2)
            self.assertEqual(result['reference_covered_bp'], 3000)
            self.assertEqual(result['reference_exactly_one_alignment_bp'], 2000)
            self.assertEqual(result['reference_covered_fraction'], '0.600000')
            self.assertEqual(result['reference_exactly_one_alignment_fraction'], '0.400000')


if __name__ == '__main__':
    unittest.main()
