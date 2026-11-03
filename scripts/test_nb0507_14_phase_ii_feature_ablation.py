"""Lightweight input and feature-set checks; no K-means on a login node."""

import tempfile
import unittest
from pathlib import Path

from nb0507_14_phase_ii_feature_ablation import MODELS, validate_candidates
from nb0507_14_phase_ii_kmeans import FEATURES


class AblationTests(unittest.TestCase):
    def test_each_ablation_removes_exactly_one_feature(self):
        self.assertEqual(tuple(MODELS["full"]), (0, 1, 2))
        self.assertEqual(set(FEATURES[i] for i in MODELS["gc_coverage"]),
                         {"gc_percent", "log10_coverage_plus_1"})
        self.assertEqual(set(FEATURES[i] for i in MODELS["gc_length"]),
                         {"gc_percent", "log10_length_bp"})
        self.assertEqual(set(FEATURES[i] for i in MODELS["length_coverage"]),
                         {"log10_length_bp", "log10_coverage_plus_1"})

    def test_candidate_list_rejects_duplicates_and_unknown_ids(self):
        ids = {f"node_{i}" for i in range(41)}
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "candidates.txt"
            path.write_text("\n".join(sorted(ids)) + "\n")
            self.assertEqual(validate_candidates(path, ids), ids)
            path.write_text("\n".join(["node_0"] * 41) + "\n")
            with self.assertRaises(ValueError):
                validate_candidates(path, ids)
            path.write_text("\n".join(sorted(ids - {"node_0"}) + ["unknown"]) + "\n")
            with self.assertRaises(ValueError):
                validate_candidates(path, ids)


if __name__ == "__main__":
    unittest.main()
