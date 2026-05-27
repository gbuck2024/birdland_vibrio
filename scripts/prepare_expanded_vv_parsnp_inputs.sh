#!/usr/bin/env bash
set -euo pipefail

# Stage the 46-genome expanded V. vulnificus panel for Parsnp.
# Gzipped FASTA files are decompressed; plain FASTA files are symlinked.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${PROJECT_DIR}"

MANIFEST="${MANIFEST:-configs/expanded_vv_46_genome_manifest.tsv}"
STAGE_DIR="${STAGE_DIR:-phylogeny/expanded_vv_46}"
GENOME_DIR="${STAGE_DIR}/genomes"
ALIGNMENT_DIR="${STAGE_DIR}/alignment"
LOG_DIR="${STAGE_DIR}/logs"
METADATA_DIR="${STAGE_DIR}/metadata"
TREE_DIR="${STAGE_DIR}/tree"
LOG_FILE="${LOG_DIR}/prepare_expanded_vv_parsnp_inputs.log"
STAGED_MANIFEST="${METADATA_DIR}/parsnp_input_manifest.tsv"
REFERENCE_RECORD="${METADATA_DIR}/parsnp_reference.txt"
DOWNSTREAM_COMMANDS="${METADATA_DIR}/downstream_tree_commands.sh"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "${LOG_FILE}"
}

require_file() {
  local path="$1"
  local label="$2"

  if [[ ! -s "${path}" ]]; then
    printf 'ERROR: %s missing or empty: %s\n' "${label}" "${path}" >&2
    exit 1
  fi
}

sanitize_id() {
  local raw="$1"
  raw="${raw// /_}"
  printf '%s' "${raw}" | tr -c 'A-Za-z0-9_.-' '_'
}

resolve_path() {
  local path="$1"

  if [[ "${path}" = /* ]]; then
    printf '%s\n' "${path}"
  else
    printf '%s/%s\n' "${PROJECT_DIR}" "${path}"
  fi
}

detect_fasta_extension() {
  local source="$1"

  case "${source}" in
    *.fasta.gz|*.fa.gz|*.fna.gz) printf '.fna\n' ;;
    *.fasta|*.fa|*.fna) printf '.fna\n' ;;
    *) printf '.fna\n' ;;
  esac
}

mkdir -p "${GENOME_DIR}" "${ALIGNMENT_DIR}" "${LOG_DIR}/slurm" "${METADATA_DIR}" "${TREE_DIR}"
: > "${LOG_FILE}"

log "START prepare_expanded_vv_parsnp_inputs.sh"
log "Project directory: ${PROJECT_DIR}"
log "Manifest: ${MANIFEST}"

require_file "${MANIFEST}" "Expanded V. vulnificus manifest"

line_count="$(wc -l < "${MANIFEST}")"
genome_count=$((line_count - 1))
if [[ "${line_count}" -ne 47 || "${genome_count}" -ne 46 ]]; then
  log "ERROR: manifest must contain 46 genomes plus one header; observed ${genome_count} genomes and ${line_count} total lines"
  exit 1
fi

read -r header < "${MANIFEST}"
first_col="$(printf '%s\n' "${header}" | cut -f1)"
second_col="$(printf '%s\n' "${header}" | cut -f2)"
if [[ -z "${first_col}" || -z "${second_col}" || "${header}" != *$'\t'* ]]; then
  log "ERROR: manifest must be tab-delimited with at least two columns: genome_id and FASTA path"
  exit 1
fi

printf 'genome_id\tsource_fasta\tstaged_fasta\trole\tnotes\n' > "${STAGED_MANIFEST}"

staged_count=0
reference_id=""
reference_staged=""

while IFS=$'\t' read -r genome_id fasta_path rest; do
  [[ -n "${genome_id}" ]] || continue

  source_fasta="$(resolve_path "${fasta_path}")"
  require_file "${source_fasta}" "Genome FASTA for ${genome_id}"

  clean_id="$(sanitize_id "${genome_id}")"
  staged_rel="${GENOME_DIR}/${clean_id}$(detect_fasta_extension "${source_fasta}")"
  staged_abs="${PROJECT_DIR}/${staged_rel}"

  if [[ "${source_fasta}" == *.gz ]]; then
    if [[ ! -s "${staged_abs}" || "${source_fasta}" -nt "${staged_abs}" ]]; then
      log "Decompressing ${genome_id}: ${fasta_path} -> ${staged_rel}"
      tmp_file="${staged_abs}.tmp"
      gzip -dc "${source_fasta}" > "${tmp_file}"
      mv "${tmp_file}" "${staged_abs}"
    else
      log "Keeping existing decompressed FASTA: ${staged_rel}"
    fi
  else
    rel_target="$(realpath --relative-to="${GENOME_DIR}" "${source_fasta}")"
    ln -sfn "${rel_target}" "${staged_abs}"
    log "Symlinked ${genome_id}: ${staged_rel}"
  fi

  require_file "${staged_abs}" "Staged FASTA for ${genome_id}"
  if ! grep -q '^>' "${staged_abs}"; then
    log "ERROR: staged FASTA has no sequence headers: ${staged_rel}"
    exit 1
  fi

  role="query"
  if [[ "${genome_id}" == *ATCC*27562* || "${genome_id}" == *atcc*27562* || "${rest}" == *ATCC*27562* || "${rest}" == *atcc*27562* ]]; then
    role="parsnp_reference"
    reference_id="${genome_id}"
    reference_staged="${staged_rel}"
  fi

  notes="${rest//$'\t'/; }"
  printf '%s\t%s\t%s\t%s\t%s\n' "${genome_id}" "${fasta_path}" "${staged_rel}" "${role}" "${notes}" >> "${STAGED_MANIFEST}"
  staged_count=$((staged_count + 1))
done < <(tail -n +2 "${MANIFEST}")

if [[ "${staged_count}" -ne 46 ]]; then
  log "ERROR: expected to stage 46 genomes; staged ${staged_count}"
  exit 1
fi

if [[ -z "${reference_staged}" ]]; then
  log "ERROR: ATCC 27562 was not found in the manifest; Parsnp reference was not selected"
  exit 1
fi

printf 'reference_id\tstaged_fasta\n%s\t%s\n' "${reference_id}" "${reference_staged}" > "${REFERENCE_RECORD}"

cat > "${DOWNSTREAM_COMMANDS}" <<'COMMANDS'
#!/usr/bin/env bash
set -euo pipefail

# Placeholder maximum-likelihood tree commands for after Parsnp alignment review.
# Do not run these until the Parsnp XMFA has been converted or otherwise prepared
# into a tree-builder-compatible core-genome alignment FASTA/PHYLIP.

CORE_ALIGNMENT="phylogeny/expanded_vv_46/alignment/core_genome_alignment.fasta"
IQTREE_PREFIX="phylogeny/expanded_vv_46/tree/iqtree_expanded_vv_46"
RAXML_PREFIX="raxmlng_expanded_vv_46"
RAXML_DIR="phylogeny/expanded_vv_46/tree"

singularity exec containers/iqtree_2.4.0.sif iqtree2 \
  -s "${CORE_ALIGNMENT}" \
  -m MFP \
  -B 1000 \
  -alrt 1000 \
  -T AUTO \
  --prefix "${IQTREE_PREFIX}"

singularity exec containers/raxmlng_2.0.0.sif raxml-ng \
  --all \
  --msa "${CORE_ALIGNMENT}" \
  --model GTR+G \
  --bs-trees 100 \
  --threads auto \
  --prefix "${RAXML_PREFIX}" \
  --redo \
  --tree pars{10},rand{10} \
  --working-dir "${RAXML_DIR}"
COMMANDS
chmod +x "${DOWNSTREAM_COMMANDS}"

log "Staged genomes: ${staged_count}"
log "Parsnp reference: ${reference_id} -> ${reference_staged}"
log "Staged manifest: ${STAGED_MANIFEST}"
log "Downstream placeholder commands: ${DOWNSTREAM_COMMANDS}"
log "END prepare_expanded_vv_parsnp_inputs.sh"
