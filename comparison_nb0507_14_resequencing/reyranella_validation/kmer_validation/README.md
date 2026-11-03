# Independent 31-mer validation

**Question.** Do exact candidate-specific sequence markers from the old
downsampled NB0507-14 assembly occur in the validated depth-matched old and
new read pairs? This tests read support without alignment. The old assembly
was built from old reads, so marker discovery still favors the old dataset.

**Inputs.** The two-row manifest is
`../../manifests/reyranella_read_mapping_depth_matched.tsv`. Its old
downsampled and new `SRR37852095_L7` FASTQs were each audited at 914,516
synchronized pairs in the completed `../read_mapping_depth_matched/` stage.
The workflow checks their recorded SHA-256 values again. Marker discovery uses
the entire 13,807-contig old assembly and the 41 candidate IDs in
`../reyranella_1kb_ids.txt`; input file checksums are pinned in the script.
These are matched-isolate sequencing datasets, not biological replicates.

**Method.** `scripts/reyranella_kmer_validation.py` uses k=31, canonicalizes
reverse complements, and skips windows containing a non-ACGT base. A marker
is *exclusive* when it occurs in exactly one candidate and in no other
assembly contig. Candidate-shared and other-contig-shared markers are counted
in a separate catalog and excluded from read support. Both R1 and R2 are
scanned. Each exact matching read window contributes one occurrence, while a
read pair contributes at most once to a candidate's supporting-pair count.
Distinct observed markers are divided by all exclusive markers for marker
fraction. Usable bases are bases in unambiguous runs of at least 31; usable
windows count all 31-mer windows in those runs. No base-quality filter is
applied. The unit of the report is one candidate contig per sequencing
dataset; overlapping k-mers are correlated, not independent observations.

**Submission.** Run the bounded synthetic tests on the login node, then
submit from the project root. The log directory must exist before `sbatch`:

```bash
python3 -m unittest discover -s scripts -p 'test_reyranella_kmer_validation.py' -v
mkdir -p comparison_nb0507_14_resequencing/reyranella_validation/kmer_validation/logs
sbatch scripts/reyranella_kmer_validation.slurm
```

The batch job checks FASTQ identity, gzip integrity, structure, mate order,
and exact pair counts. It refuses prior metrics/reports and uses a run lock.
If it fails, retain its partial outputs and inspect the job log before using
a newly named stage for any rerun. It does not touch either read-mapping stage.

**Expected outputs and QC.** `reports/candidate_31mer_support.tsv` contains
82 candidate-by-dataset rows. `reports/marker_classes.tsv` records distinct
marker classes. `metrics/input_audit.tsv` has two rows with FASTQ hashes,
pair counts, sequenced bases, usable bases, and usable windows.
`metrics/parameters.tsv` records k, definitions, input hashes, and Python
version. The job verifies the expected report and audit row counts before
reporting completion. A successful SLURM exit and nonempty outputs should be
checked before interpreting results.

**Interpretation and next decision.** Compare old and new exclusive marker
fractions, occurrences, and supporting pairs alongside usable bases and
mapping results. No detected exact markers at this depth means none were
detected under this method; sequencing error, low depth, and sequence
divergence limit sensitivity. Shared-marker counts signal ambiguity, not
candidate-specific support. Follow up with reciprocal or alternative
reference alignment before assigning a biological or taxonomic cause.
