Scope and source of truth
- Project root: /work/VibrioVulnificus/gbuck/20260105_Buck-wgs/.
- Read PROJECT_BRIEF.md before making project-level decisions. Consult NEXT_STEPS.md and WORK_COMPLETED.md to understand current status; do not treat documentation as proof of successful execution.
- This file governs work throughout the repository. If the user's current explicit request conflicts with a non-safety preference here, ask before making consequential changes; never silently bypass data-protection rules.
- Work from the project root and prefer relative paths in scripts, manifests, and documentation. Scripts live in scripts/.
- Treat sample names, isolate identities, sequencing runs, and reference accessions as distinct entities. Never assume two datasets represent independent biological samples or identical biological material without documented provenance.
Data protection and organization
- Never modify, rename, move, truncate, or delete anything in fq_raw/. Treat all original FASTQ and externally received sequencing data as immutable.
- Preserve original reads, established analyses, BAMs, reports, manifests, and logs. Never overwrite an existing run to accommodate a new experiment; create a separately named stage/run directory.
- Before writing outputs, check for existing paths and refuse accidental replacement. Use run locks where appropriate; avoid destructive cleanup. Ask for explicit permission before deleting or replacing existing files.
- Separate raw inputs, intermediate outputs, metrics, interpreted reports, figures, and logs. Minimize unnecessary directory nesting and follow https://github.com/tamucc-comp-bio/how_to/blob/main/howto_organize_data.md where compatible with existing project layout.
- Use predictable stage-specific output paths and filenames incorporating sample/run identifiers. Maintain manifests that map each result back to exact input FASTQs, references, and parameters.
- Avoid large intermediate files in the Git repository. Use checksums to record input/reference identity when practical.
Git repository
- Track source code, small configuration/manifests (without secrets), documentation, tested workflow definitions, and appropriately sized interpreted reports or summaries.
- Do not commit raw or trimmed FASTQs (*.fq, *.fastq, and compressed variants), large BAM/CRAM/SAM files and indices, FASTA assemblies/reference databases unless expressly intended and sized appropriately, FastQC HTML/ZIP, temporary files, secrets, or runtime logs (*.log, slurm-*.out, *.out, *.err). Use .gitignore and verify git status/`git diff` before proposing a commit.
- Do not stage, commit, push, force-push, or rewrite Git history unless explicitly requested.
Execution policy and SLURM
- Use SLURM for compute-heavy work (read mapping, genome assembly, whole-dataset k-mer counting, large BLAST operations, large feature extraction). Never run heavy computations on a CREST login node.
- Write and validate SLURM scripts, but do not submit or cancel jobs unless the user explicitly requests that action. Give the exact sbatch command for manual submission.
- Set explicit job name, partition, walltime, CPUs, memory, and stage-specific %j stdout/stderr paths. Validate that log directories exist before submission.
- SLURM may spool submitted scripts. Resolve the project root with SLURM_SUBMIT_DIR for root-submitted jobs; do not derive the root from BASH_SOURCE[0] inside a batch script.
- Use set -euo pipefail, validate dependencies/modules and expected paths, and fail clearly on errors. Validate completed jobs using exit status and required outputs, not just a success message.
- Do not infer the location of outputs from a prior run. Inspect the actual job script, manifest, logs, and stage directory.
- Prefer small, bounded login-node checks (file headers, manifests, grep, head, sacct) and clearly separate them from batch workloads.
Input validation and provenance
- Preserve R1/R2 pairing at every processing stage. Validate gzip integrity, FASTQ structure, synchronized read names and ordering, and exact pair counts before substantial analysis.
- Validate that every manifest points to the intended files. In particular, distinguish full original old NB0507-14 reads, downsampled old reads, and new SRR37852095_L7 reads.
- Document sequencing center/run, read processing, whether datasets are independently sequenced, and whether samples are believed to be the same biological isolate. Flag uncertain provenance rather than asserting it.
- Verify reference FASTA identity, length/contig count, and checksums; record accession and version for externally retrieved references.
- Record software names/versions, command-line options, random seeds, filtering thresholds, input read counts, and hashes where feasible. Store per-run parameters.tsv and/or equivalent provenance metadata.
- Never infer that equal read-pair counts guarantee equal sequenced bases, quality, coverage, or biological sampling depth; quantify these separately.
Workflow stages
- Follow the general workflow in PROJECT_BRIEF.md where applicable: raw FastQC, QC extraction/interpretation, trimming, post-trim QC, alignment/assembly, annotation, gene mining, and phylogenetics.
- Additional active stages include contamination screening, competing-reference alignment, old-versus-new read validation, alignment-free k-mer validation, and mathematical feature engineering/clustering.
- Each stage must have a clearly stated biological question, input/output contract, QC checks, computation method, results, limitations, and next decision.
- Preserve prior experiments as independent baselines; generate new outputs rather than retroactively replacing them.
NB0507-14 investigation: established context
- The old downsampled NB0507-14 assembly contains 13,807 contigs. The initial Kraken2-selected Reyranella candidate set comprises 41 contigs of at least 1,000 bp. These are candidate sequences, not confirmed species identifications.
- Candidate identifiers: comparison_nb0507_14_resequencing/reyranella_validation/reyranella_1kb_ids.txt.
- Old downsampled assembly: comparison_nb0507_14_resequencing/downsampled_old_assembly/assemblies/Buck_NB0507_14_downsampled_to_SRR37852095_L7/contigs.fasta.
- Initial competitive BLASTN tested three Reyranella references and one Enhydrobacter reference. The resulting best-hit reference preferences do not prove genus identity; reference sampling, local alignment, and MAG taxonomy can bias interpretations.
- Preserve the full-depth old-versus-new mapping experiment in comparison_nb0507_14_resequencing/reyranella_validation/read_mapping/ and the depth-matched experiment in comparison_nb0507_14_resequencing/reyranella_validation/read_mapping_depth_matched/.
- Depth-matched job 1559028 validated 914,516 paired reads per dataset. At the tested mapping settings, all 41 candidate contigs had old-read support, and none had new-read support. The old median mean depth was approximately 2.465× and median breadth at ≥5× was approximately 7.568%. Treat this as dataset-specific mapping evidence, not proof of contamination, sequence absence, organism identity, or where contamination arose.
- The depth-matched report's numreads originates in MAPQ-filtered samtools coverage; the MAPQ category counts originate in a broader samtools view alignment pass. These counts have different denominators and must not be summed as if identical. proper_pairs counts distinct paired QNAMEs, not individual read records.
- Independent validation remains necessary, especially exact/canonical k-mer support and reciprocal or alternative-reference alignment. Be mindful that the old assembly is derived from the old data and thus favors old-read mapping.
Sequence and taxonomic interpretation
- Distinguish Kraken2 taxonomic assignments, BLAST homology, best-reference bitscore preference, ANI, aligned fraction, and independent read evidence. None is interchangeable with the others.
- For BLAST comparisons, document reference accession/version, search database, alignment coverage, identity, bitscore, E-value, and whether hits are local. A best bitscore only favors one of the tested references; it is not a probability of taxonomic identity.
- Do not equate high GC, low coverage, a Kraken2 label, or an old-only signal with proven contamination. Consider technical artifacts, uneven abundance, repeat regions, reference incompleteness, sample differences, and database bias.
- Never infer the presence, absence, or allele of vcgC/`vcgE` without direct read- or assembly-supported evidence. Do not fabricate recovery of genomic information that the reads do not contain.
- Keep observed results separate from hypotheses and predictions in all notes, figures, and reports. Explicitly mark provisional classifications and unresolved evidence.
Alignment and coverage quality
- For all mapping comparisons, specify the reference used (full assembly versus selected contigs), aligner options, BAM flag filters, MAPQ threshold, base-quality threshold, mate-overlap treatment, and read-count unit (alignments, reads, read pairs, or distinct QNAMEs).
- Keep samtools coverage metrics distinct from samtools depth metrics. Match filters and overlap handling when comparing quantities, or document why they differ.
- Report at least mapped fraction, properly paired fraction, per-candidate depth, ≥1× and ≥5× breadth where feasible, MAPQ distribution, and high-quality properly paired support.
- An overall high mapping fraction does not establish where reads mapped, unique genomic origin, or absence of reads in an unaligned region.
- For zero-support claims, say no reads/markers were detected under specified conditions; consider detection limits and sequencing depth.
Alignment-free validation and computational safeguards
- When implementing k-mer validation, specify k (initially 31 unless justified otherwise), canonicalize reverse complements, exclude ambiguous k-mers, and explicitly distinguish unique candidate-specific markers from markers shared with other assembly contigs or across candidates.
- Analyze both R1 and R2, validate synchronization, and report distinct k-mers, total occurrences, supporting read pairs, marker coverage, and usable bases. Avoid double-counting a pair for the same candidate.
- Use synthetic positive/negative test reads and unit tests for reverse-complement handling, repetitive markers, and shared markers before running full datasets.
- Run whole-dataset k-mer analysis under SLURM. Preserve all existing read-mapping outputs and use a dedicated stage such as comparison_nb0507_14_resequencing/reyranella_validation/kmer_validation/.
- Note that exact k-mer absence is sensitive to sequencing errors, low depth, and sequence divergence; it does not establish biological absence.
Mathematical modeling and benchmarking
- The long-term goal is to identify/filter anomalous sequence components while retaining authentic Vibrio reads, improving downstream reassembly and read-supported vcg recovery where possible.
- Build documented feature matrices from appropriately scaled measurements (e.g., GC%, contig length, coverage, k-mer composition, reference-alignment evidence, mapping quality, and independent resequencing support). Identify the observation unit (read, contig, window, or isolate) explicitly.
- Avoid treating correlated fragments or overlapping k-mers as independent biological samples. Account for length effects, compositional constraints, depth, missing values, and reference biases.
- Consider clustering, similarity matrices, graph-based methods, symmetric matrices, and nested/block matrices only when they answer a defined biological question. Specify distance/similarity functions and validate matrix dimensions, symmetry, and expected mathematical properties.
- Keep model development, tuning, and evaluation separate: prevent train/test leakage from the same biological isolate, sequencing run, reassembly, or shared reference-derived features.
- Use confirmed same-isolate sequencing comparisons as benchmarks. NB0507-8 and Mullis 18061 are considered a same-isolate comparison in the current project; proposed BI0607-1/Mullis 18023 and BS0607-9/Mullis 18032 pairs remain unconfirmed until provenance is checked.
- Validate using appropriate measures such as ANI with aligned fraction, mapping/read retention, genome completeness and contamination indicators, assembly errors, and supported vcgC/`vcgE` allele recovery. Use synthetic known-mixture controls when feasible.
- Do not force an ambiguous isolate to be V. vulnificus merely because it is the target organism; consider competing Vibrio species and mixed assemblies.
Script engineering and testing
- Store scripts in scripts/; use reusable functions, clear entry points and CLI arguments rather than hard-coded sample paths. Use manifests for run-specific inputs.
- Document purpose, biological question, input schema, outputs, algorithms, filtering semantics, and how to reproduce each run.
- Write parameter and input validation, clear error messages, and smoke/unit tests. Avoid silently accepting empty or malformed files, inconsistent identifiers, unequal pairs when a matched design is expected, or incorrect reference versions.
- Ensure scripts can be executed safely multiple times without overwriting completed outputs. Validate expected output counts and content before declaring success.
- Prefer straightforward Python and established tools; avoid adding dependencies without confirming HPC availability.
Reporting and documentation
- After verified milestones, update WORK_COMPLETED.md with commands/scripts, inputs, parameters, SLURM job ID/status, output paths, key numerical findings, and caveats; update NEXT_STEPS.md with prioritized follow-up checks.
- Never describe planned, submitted, running, failed, or unverified experiments as completed. Identify exactly which dataset and stage generated each result.
- Write concise interpretations with separate sections for observation, possible explanation, limitations, and next validation. Do not overstate causal conclusions.
- For scientific outputs, include a reproducible summary table and units; retain relevant source TSVs and scripts. Avoid manual-only steps unless explicitly recorded, including NCBI BLAST database, query/accession, selected hits, and reference retrieval.
Agent behavior
- Before substantial edits, inspect relevant files, manifests, output destinations, and current Git changes. Summarize intended edits when they affect scientific logic or existing workflows.
- Implement and test scripts without submitting compute-heavy jobs. Provide the user with the exact job-submission command and expected report paths.
- If a command fails, stop the dependent workflow, report the actual error, and propose a targeted fix. Do not claim success from file existence alone.
- Do not guess missing sample provenance, biological identity, result values, or command output. Ask or flag uncertainty when a missing fact affects validity.
- Never make destructive changes, remove safeguards, or overwrite completed experimental outputs without explicit authorization.
