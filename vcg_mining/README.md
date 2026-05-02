# vcg Mining Stage

This stage is reserved for nucleotide BLAST searches of confirmed
`Vibrio vulnificus` assemblies against saved `vcg` reference alleles. The
initial focus is the same 3 best subsampled assemblies already selected for the
assembly-confirmation path:

- `Buck_BS0607_9_WKDL250009588-1A_233TFCLT4_L7_50x`
- `Buck_CB0707_82_WKDL250009588-1A_233TFCLT4_L7_25x`
- `Buck_NB0507_8_WKDL250009588-1A_233TFCLT4_L7_100x`

## Intended inputs

- `configs/vcg_mining_manifest.tsv`
- `assembly_filtered_subsampled_isolate/assemblies/<sample_id>/scaffolds.fasta`
- `vcg_mining/references/vcg_reference_alleles.fasta`

The saved manifest currently points at the `scaffolds.fasta` assembly for each
selected sample.

## Required reference FASTA

The BLAST workflow intentionally does not create or guess the vcg references.
It will fail clearly if this file is missing or empty:

- `vcg_mining/references/vcg_reference_alleles.fasta`

Expected content:

- nucleotide FASTA entries for the `vcgC` and `vcgE` alleles to search
- stable FASTA headers, because the BLAST and summary outputs report `qseqid`
  directly from those headers

## Intended outputs

- `vcg_mining/results/<sample_id>.vcg.blast.tsv`
- `vcg_mining/results/vcg_best_hits_summary.tsv`
- `vcg_mining/results/blast_db/`
- `vcg_mining/logs/slurm/vcg_mining_<jobid>_<taskid>.out`
- `vcg_mining/logs/slurm/vcg_mining_<jobid>_<taskid>.err`
- `vcg_mining/logs/<sample_id>.makeblastdb.log`

Per-sample BLAST outputs are written in tabular format with these columns:

- `qseqid`
- `sseqid`
- `pident`
- `length`
- `qstart`
- `qend`
- `sstart`
- `send`
- `evalue`
- `bitscore`
- `qcovs`

## Tool and behavior

- Primary search tool: `blastn`
- Reference query file: `vcg_mining/references/vcg_reference_alleles.fasta`
- Assembly target file: each manifest-listed scaffold FASTA, converted into a
  stage-local nucleotide BLAST database under `vcg_mining/results/blast_db/`
- The workflow first looks for `blastn` and `makeblastdb` in `PATH`
- If BLAST is not already available, the script tries to load an environment
  module such as `blast+`, `blast`, or `ncbi-blast+`
- The script writes each BLAST result to a temporary file and only moves it
  into place after BLAST exits cleanly

## Planned submission pattern

```bash
sbatch --array=0-2 scripts/vcg_mining_array.slurm
sbatch --export=ALL,VCG_MODE=summary scripts/vcg_mining_array.slurm
```

No BLAST searches have been run yet in this stage.
