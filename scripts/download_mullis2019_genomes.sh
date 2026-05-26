#!/usr/bin/env bash
set -euo pipefail

# Download the Mullis et al. 2019 V. vulnificus genome FASTA files from
# NCBI Assembly FTP URLs listed in the resolved project metadata table.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

METADATA="${PROJECT_DIR}/reference/expanded_vv/metadata/mullis2019_genome_downloads.tsv"
DOWNLOAD_DIR="${PROJECT_DIR}/reference/expanded_vv/downloads"
GENOME_DIR="${PROJECT_DIR}/reference/expanded_vv/genomes"
LOG_FILE="${DOWNLOAD_DIR}/download_mullis2019.log"

mkdir -p "${DOWNLOAD_DIR}" "${GENOME_DIR}"

log() {
    printf '[%(%Y-%m-%d %H:%M:%S)T] %s\n' -1 "$*" | tee -a "${LOG_FILE}"
}

gzip_valid() {
    local file="$1"
    [[ -s "${file}" ]] && gzip -t "${file}" >/dev/null 2>&1
}

download_file() {
    local url="$1"
    local dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -L -C - -o "${dest}" "${url}"
    elif command -v wget >/dev/null 2>&1; then
        wget -c -O "${dest}" "${url}"
    else
        log "ERROR: neither curl nor wget is available"
        return 1
    fi
}

link_valid_genome() {
    local downloaded="$1"
    local link_path="$2"
    local rel_target="../downloads/$(basename "${downloaded}")"

    ln -sfn "${rel_target}" "${link_path}"
    log "Symlinked valid genome: ${link_path#${PROJECT_DIR}/}"
}

if [[ ! -s "${METADATA}" ]]; then
    log "ERROR: metadata table missing or empty: ${METADATA#${PROJECT_DIR}/}"
    exit 1
fi

log "Starting Mullis et al. 2019 genome download scaffold"
log "Metadata: ${METADATA#${PROJECT_DIR}/}"

status=0
rows=0
downloaded=0
skipped=0

{
    read -r header
    expected_header=$'isolate\twgs_accession\tassembly_accession\tftp_url\tlocal_filename\tprovenance\tnotes'
    if [[ "${header}" != "${expected_header}" ]]; then
        log "ERROR: unexpected metadata header: ${header}"
        exit 2
    fi

    while IFS=$'\t' read -r isolate wgs_accession assembly_accession ftp_url local_filename provenance notes; do
        [[ -n "${isolate}" ]] || continue
        rows=$((rows + 1))

        if [[ -z "${ftp_url}" || -z "${local_filename}" || "${ftp_url}" == "NA" || "${local_filename}" == "NA" ]]; then
            log "Skipping unresolved row: isolate ${isolate}, WGS ${wgs_accession}"
            skipped=$((skipped + 1))
            continue
        fi

        dest="${DOWNLOAD_DIR}/${local_filename}"
        link_path="${GENOME_DIR}/${local_filename}"

        if gzip_valid "${dest}"; then
            log "Already downloaded and gzip-valid: ${dest#${PROJECT_DIR}/}"
            link_valid_genome "${dest}" "${link_path}"
            skipped=$((skipped + 1))
            continue
        fi

        log "Downloading isolate ${isolate}, WGS ${wgs_accession}, assembly ${assembly_accession}"
        log "URL: ${ftp_url}"

        if download_file "${ftp_url}" "${dest}" && gzip_valid "${dest}"; then
            log "Validated gzip: ${dest#${PROJECT_DIR}/}"
            link_valid_genome "${dest}" "${link_path}"
            downloaded=$((downloaded + 1))
        else
            log "ERROR: download or gzip validation failed for isolate ${isolate}: ${dest#${PROJECT_DIR}/}"
            status=1
        fi
    done
} < "${METADATA}"

log "Completed Mullis et al. 2019 genome download scaffold"
log "Rows processed: ${rows}; newly downloaded: ${downloaded}; already present/skipped: ${skipped}"

exit "${status}"
