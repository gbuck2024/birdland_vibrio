#!/usr/bin/env bash
set -euo pipefail

# Validate that the Mullis et al. 2019 expanded reference scaffold has the
# expected metadata rows, downloaded genome FASTA files, and genome symlinks.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

METADATA="${PROJECT_DIR}/reference/expanded_vv/metadata/mullis2019_genome_downloads.tsv"
WGS_LIST="${PROJECT_DIR}/reference/expanded_vv/metadata/mullis2019_wgs_accessions.txt"
DOWNLOAD_DIR="${PROJECT_DIR}/reference/expanded_vv/downloads"
GENOME_DIR="${PROJECT_DIR}/reference/expanded_vv/genomes"

failures=0
metadata_rows=0
valid_downloads=0
valid_links=0
unresolved_rows=0

report_error() {
    printf 'ERROR: %s\n' "$*" >&2
    failures=$((failures + 1))
}

gzip_valid() {
    local file="$1"
    [[ -s "${file}" ]] && gzip -t "${file}" >/dev/null 2>&1
}

require_file() {
    local file="$1"
    if [[ ! -s "${file}" ]]; then
        report_error "missing or empty file: ${file#${PROJECT_DIR}/}"
        return 1
    fi
}

require_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        report_error "missing directory: ${dir#${PROJECT_DIR}/}"
        return 1
    fi
}

require_file "${METADATA}" || true
require_file "${WGS_LIST}" || true
require_dir "${DOWNLOAD_DIR}" || true
require_dir "${GENOME_DIR}" || true

if (( failures > 0 )); then
    exit 1
fi

expected_header=$'isolate\twgs_accession\tassembly_accession\tftp_url\tlocal_filename\tprovenance\tnotes'
read -r header < "${METADATA}"
if [[ "${header}" != "${expected_header}" ]]; then
    report_error "unexpected metadata header in ${METADATA#${PROJECT_DIR}/}"
fi

while IFS=$'\t' read -r isolate wgs_accession assembly_accession ftp_url local_filename provenance notes; do
    [[ -n "${isolate}" ]] || continue
    metadata_rows=$((metadata_rows + 1))

    if [[ -z "${ftp_url}" || -z "${local_filename}" || "${ftp_url}" == "NA" || "${local_filename}" == "NA" ]]; then
        unresolved_rows=$((unresolved_rows + 1))
        continue
    fi

    download_path="${DOWNLOAD_DIR}/${local_filename}"
    genome_path="${GENOME_DIR}/${local_filename}"

    if gzip_valid "${download_path}"; then
        valid_downloads=$((valid_downloads + 1))
    else
        report_error "missing, empty, or invalid gzip: ${download_path#${PROJECT_DIR}/}"
    fi

    if [[ -L "${genome_path}" || -f "${genome_path}" ]]; then
        if gzip_valid "${genome_path}"; then
            valid_links=$((valid_links + 1))
        else
            report_error "genome entry is present but not gzip-valid: ${genome_path#${PROJECT_DIR}/}"
        fi

        if [[ -L "${genome_path}" ]]; then
            resolved_target="$(readlink -f "${genome_path}")"
            resolved_download="$(readlink -f "${download_path}")"
            if [[ "${resolved_target}" != "${resolved_download}" ]]; then
                report_error "genome symlink does not point to matching download: ${genome_path#${PROJECT_DIR}/}"
            fi
        fi
    else
        report_error "missing genome entry: ${genome_path#${PROJECT_DIR}/}"
    fi
done < <(tail -n +2 "${METADATA}")

wgs_rows=$(wc -l < "${WGS_LIST}")
if [[ "${wgs_rows}" -ne "${metadata_rows}" ]]; then
    report_error "WGS accession count (${wgs_rows}) does not match metadata rows (${metadata_rows})"
fi

expected_downloads=$((metadata_rows - unresolved_rows))

printf 'Mullis et al. 2019 genome validation summary\n'
printf 'Metadata rows: %d\n' "${metadata_rows}"
printf 'Unresolved rows skipped: %d\n' "${unresolved_rows}"
printf 'Expected downloadable genomes: %d\n' "${expected_downloads}"
printf 'Valid downloads: %d\n' "${valid_downloads}"
printf 'Valid genome entries: %d\n' "${valid_links}"

if (( failures > 0 )); then
    printf 'Validation failed with %d problem(s).\n' "${failures}" >&2
    exit 1
fi

printf 'Validation passed.\n'
