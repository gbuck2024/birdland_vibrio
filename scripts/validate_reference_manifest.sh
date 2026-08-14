#!/usr/bin/env bash
set -euo pipefail

# Validate the project-wide reference manifest used as a dictionary for
# available reference FASTA files. This is lightweight and safe for login use.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST="${1:-configs/reference_sequence_manifest.tsv}"

cd "${PROJECT_DIR}"

failures=0
rows=0
gzip_rows=0
plain_fasta_rows=0
indexed_plain_fasta_rows=0

report_error() {
    printf 'ERROR: %s\n' "$*" >&2
    failures=$((failures + 1))
}

if [[ ! -s "${MANIFEST}" ]]; then
    report_error "missing or empty manifest: ${MANIFEST}"
    exit 1
fi

expected_header=$'reference_id\treference_fasta\treference_format\tnotes'
read -r header < "${MANIFEST}"
if [[ "${header}" != "${expected_header}" ]]; then
    report_error "unexpected manifest header in ${MANIFEST}"
fi

while IFS=$'\t' read -r reference_id reference_fasta reference_format notes; do
    [[ -n "${reference_id}" ]] || continue
    rows=$((rows + 1))

    if [[ -z "${reference_fasta}" || -z "${reference_format}" ]]; then
        report_error "malformed row for reference_id '${reference_id}'"
        continue
    fi

    if [[ ! -s "${reference_fasta}" ]]; then
        report_error "missing or empty reference FASTA for ${reference_id}: ${reference_fasta}"
        continue
    fi

    case "${reference_fasta}" in
        *.gz)
            if gzip -t "${reference_fasta}" >/dev/null 2>&1; then
                gzip_rows=$((gzip_rows + 1))
            else
                report_error "invalid gzip FASTA for ${reference_id}: ${reference_fasta}"
            fi
            ;;
        *)
            if grep -qm 1 '^>' "${reference_fasta}"; then
                plain_fasta_rows=$((plain_fasta_rows + 1))
            else
                report_error "plain FASTA lacks a header line for ${reference_id}: ${reference_fasta}"
            fi

            if [[ -s "${reference_fasta}.fai" ]]; then
                indexed_plain_fasta_rows=$((indexed_plain_fasta_rows + 1))
            else
                report_error "missing FASTA index for plain reference ${reference_id}: ${reference_fasta}.fai"
            fi
            ;;
    esac
done < <(tail -n +2 "${MANIFEST}")

printf 'Reference manifest validation summary\n'
printf 'Manifest: %s\n' "${MANIFEST}"
printf 'Rows: %d\n' "${rows}"
printf 'Plain FASTA rows: %d\n' "${plain_fasta_rows}"
printf 'Indexed plain FASTA rows: %d\n' "${indexed_plain_fasta_rows}"
printf 'Gzip FASTA rows: %d\n' "${gzip_rows}"

if (( failures > 0 )); then
    printf 'Validation failed with %d problem(s).\n' "${failures}" >&2
    exit 1
fi

printf 'Validation passed.\n'
