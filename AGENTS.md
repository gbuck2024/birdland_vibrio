Codex operating rules for Vibrio WGS project

Location
- Project directory: /work/VibrioVulnificus/gbuck/20260105_Buck-wgs
- Raw reads: fq_raw/
- Outputs: create new directories for each step

Project reference
- See PROJECT_BRIEF.md for full project description and goals

Working rules
- Never modify files in fq_raw/
- All outputs must go into new directories within /work/VibrioVulnificus/gbuck/
- Scripts must be reusable and clearly named
- Use SLURM for all compute-heavy tasks (no heavy work on login node)
- Always log actions and outputs
- Do not overwrite logs; append to them

SLURM rules
- Check job status within 1–2 minutes of submission
- Capture stdout and stderr logs for every job
- Use multiple CPUs when appropriate
- Use arrays when processing multiple samples

Data handling
- Always treat forward and reverse reads as pairs
- Validate input files before running jobs
- Outputs must clearly map to input sample names

Data organization
- Use the guidance in https://github.com/tamucc-comp-bio/how_to/blob/main/howto_organize_data.md as a guide for organizing biological data.
- Minimize directory nesting per those guidelines.

Working agreement
- Keep actions small and reversible; confirm before cancellations or resubmissions.
- Check new jobs within 1-2 minutes for early failure and note status in IN_PROGRESS.md.
- Favor array jobs for per-file work; avoid `find` when enumerating reads.
- Use scratch/local staging only when it speeds I/O and fits space; leave original DB/library intact.
- Log step boundaries with timestamped `echo` in SLURM outputs for fast troubleshooting.
- Update NEXT_STEPS.md and WORK_COMPLETED.md after each milestone. Make these directories within /work/VibrioVulnificus/gbuck
- Organize scripts with short comments explaining the code used to ensure reproducibility.

Reproducibility
- Record all parameters used
- Save all scripts within /work/VibrioVulnificus/gbuck/20260105_Buck-wgs/scripts/ for each script used.
- Ensure all outputs can be regenerated from scripts

Pipeline expectations
- Follow workflow defined in PROJECT_BRIEF.md
- Current completed step: FastQC on trimmed sequences
- Next step: Develop scripts identical to the current scripts that analyzed FASTQC on raw reads. 

Behavior expectations
- Do not assume success—verify outputs
- If an error occurs, stop and report it
- Suggest improvements but do not make destructive changes without confirmation
