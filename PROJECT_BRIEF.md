Project Title

Bioinformatic Characterization of Vibrio vulnificus Isolates Using Whole-Genome Sequencing

Background / Abstract

The genus Vibrio consists of marine, Gram-negative, halophilic, curved rod-shaped bacteria commonly found in warm coastal and estuarine environments. Among them, Vibrio vulnificus is an opportunistic human pathogen capable of causing severe wound infections and septicemia following exposure to contaminated seawater or the consumption of raw or undercooked seafood. Vibrio vulnificus exhibits substantial strain-level diversity, and differences among genotypes may contribute to variation in virulence potential, making classification difficult. In addition, as observed in other bacterial groups, Vibrio genomes may share characteristics across species boundaries, further complicating speciation and classification.

Whole-genome sequencing (WGS) is an essential tool for characterizing microbial isolates, including members of the genus Vibrio. However, raw sequencing data consist of thousands to millions of short DNA fragments that must undergo extensive computational processing before meaningful biological interpretation is possible. In this project, we are developing a bioinformatic pipeline to process Vibrio isolates sequenced by the Genomics Core Lab in order to better understand strain diversity, virulence potential, and evolutionary relationships.

Raw WGS reads will first be evaluated using FastQC and then trimmed to remove low-quality bases and adapter contamination. The processed reads will then be used for genome assembly and downstream comparative genomic analysis. The project aims to identify genomic features associated with virulence, including genes such as vcgC and vcgE, along with additional virulence-associated markers, antibiotic resistance determinants, and possible single-nucleotide variants. These data may provide insight into evolutionary patterns across strains. Phylogenetic relationships among isolates will also be examined using maximum-likelihood approaches within the pipeline. Overall, this workflow is intended to transform raw sequencing data into biologically meaningful results that improve the characterization of strain diversity, virulence potential, and evolutionary relationships within Vibrio.

Current Direction

Current efforts are focused on detecting vcgC and vcgE genes in the sequencing data, along with examining Vibrio vulnificus sequences described in the Samsa et al. manuscript. Additional comparative work may include the 42 isolates described in Mullis et al. (2019), together with other relevant Vibrio strains.

Main Goal

To process raw WGS data and identify genomic features associated with virulence, diversity, and classification in Vibrio vulnificus isolates.

Planned Workflow

Step 1: Quality Control (Completed)
Tool: FastQC

Step 2: Read Trimming
Tool: Trimmomatic
Purpose: Remove adapter contamination and low-quality bases

Step 3: Post-trim Quality Control
Tool: FastQC

Step 4: Genome Assembly
Tool: SPAdes

Step 5: Genome Annotation
Tool: Prokka

Step 6: Gene Analysis
Tool: BLAST
Targets: vvhA, rpoS, ompU, vcgC, vcgE

Step 7: Comparative Analysis
Identify genomic differences among strains
Evaluate virulence-associated features
Perform phylogenetic analysis

Data Structure

Each sample contains paired-end Illumina sequencing reads:
*_L7_1.fq.gz = forward reads
*_L7_2.fq.gz = reverse reads

File sizes range from approximately 8–16 GB per file.

Raw reads are stored in:
/work/gbuck/20260105_Buck-wgs/fq_raw/

Raw data must never be modified.

Computing Environment

System: TAMU-CC CREST HPC
Scheduler: SLURM

Project Rules

Do not modify files in fq_raw/
All outputs must be written to new directories
Scripts must be reusable and well documented
Use SLURM for all compute-heavy tasks
Maintain a running log of all actions and outputs
Do not overwrite logs; append to preserve history
Every step must produce log files
All parameters must be recorded
Outputs must be traceable to inputs

Current Tasks

Generate SLURM scripts for read trimming
Automate processing of all samples
Ensure correct pairing of forward and reverse reads
Suggest improvements to the pipeline as needed
