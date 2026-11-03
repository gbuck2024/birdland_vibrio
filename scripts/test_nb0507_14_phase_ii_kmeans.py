#!/usr/bin/env python3
"""Lightweight feature validation tests; no clustering runs on login nodes."""

import unittest

from nb0507_14_phase_ii_kmeans import feature_values


class FeatureTests(unittest.TestCase):
    def test_transforms_include_zero_coverage(self):
        rows = [{"contig_id": "a", "length_bp": "100", "gc_percent": "40",
                 "coverage": "0"},
                {"contig_id": "b", "length_bp": "1000", "gc_percent": "60",
                 "coverage": "99"}]
        self.assertEqual(feature_values(rows), [(40, 2, 0), (60, 3, 2)])

    def test_rejects_invalid_values(self):
        base = {"contig_id": "a", "length_bp": "100", "gc_percent": "40",
                "coverage": "1"}
        for change in ({"length_bp": "0"}, {"gc_percent": "nan"},
                       {"gc_percent": "101"}, {"coverage": "-1"},
                       {"coverage": "inf"}):
            with self.subTest(change=change), self.assertRaises(ValueError):
                feature_values([{**base, **change}])


if __name__ == "__main__":
    unittest.main()
