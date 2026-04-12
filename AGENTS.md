Codex operating rules for Vibrio WGS project

Location
- Project directory: /work/VibrioVulnificus/gbuck/20260105_Buck-wgs/
- Raw reads: fq_raw/
- Scripts: scripts/
- Outputs: Create stage-specific directories. Do not mix outputs across steps.

Project reference
- See PROJECT_BRIEF.md for full project description and goals.

Core working rules
- Never modify files in fq_raw/
- All outputs must go into clearly named, stage-specific directories.
- Scripts must be reusable, modular, and clearly named.
- prefer relative paths when possible.

Git repository
- Track scripts, documentation, configs, and interpreted reports.
- Must NOT contain:
  - *.fq.gz, *.fastq.gz 
  - FastQC HTML/ZIP
  - Trimmed read files
  - Logs (*.log, slurm-*.out, *.err)

SLURM
- Use SLURM for all compute-heavy tasks. Do not run heavy jobs on the login node
- Do not run SLURM scripts, only write and ensure they are ready for submission.

Data handling
- Treat forward (R1) and reverse (R2) reads as pairs
- Validate input files before running jobs
- Outputs must clearly map to input sample names
- Preserve pairing integrity during all steps

Data organization
- Use and follow https://github.com/tamucc-comp-bio/how_to/blob/main/howto_organize_data.md
- Minimize unnecessary directory nesting
- Use consistent naming across all steps
- Seperate:
  - Raw data
  - Intermediate outputs
  - Interpreted reports

Script rules
- All scripts must be saved in /work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/
- Each script must:
  - Include short comments explaining purpose and logic
  - Be reusable across samples
  - Avoid hardcoding sample-specific values

Workflow
- Follow workflow defined in PROJECT_BRIEF.md
- Pipeline stages include:
  1. Raw FastQC
  2. FastQC extraction
  3. QC interpretation
  4. Trimmomatic trimming
  5. Post-trim FastQC
  6. Post-trim QC interpretation
  7. Alignment or assembly
  8. Annotation
  9. Gene mining
  10. Phylogenetics 
- Verify completion using expected files.

Reproducibility
- Record all parameters used
- Saved all scripts used
- Ensure all outputs can be regenerated from scripts
- Do not rely on manual terminal history
- Update documentation after each milestone:
  - NEXT_STEPS.md
  - WORK_COMPLETED.md

Behavior
- Do not assume success, verify outputs.
- If an error occurs, stop and report it
- Suggest improvements but do not make destructive changes without confirmation.
- Flag uncertainty instead of guessing

