#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
fastqc_dir="${project_dir}/fastqc"
extract_dir="${project_dir}/fastqc_extracted"
log_file="${extract_dir}/extract_fastqc_reports.log"

mkdir -p "${extract_dir}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "${log_file}"
}

log "Starting FastQC archive extraction"

zip_count=0
for zip_path in "${fastqc_dir}"/*_fastqc.zip; do
  if [[ ! -f "${zip_path}" ]]; then
    log "No FastQC zip archives found in ${fastqc_dir}"
    exit 1
  fi

  zip_count=$((zip_count + 1))
  base_name="$(basename "${zip_path}" .zip)"
  target_dir="${extract_dir}/${base_name}"

  log "Extracting ${base_name}.zip to ${target_dir}"
  rm -rf "${target_dir}.tmp"
  mkdir -p "${target_dir}.tmp"
  unzip -q -o "${zip_path}" -d "${target_dir}.tmp"
  extracted_root="${target_dir}.tmp/${base_name}"

  if [[ ! -f "${extracted_root}/summary.txt" || ! -f "${extracted_root}/fastqc_data.txt" ]]; then
    log "Missing expected FastQC files in ${zip_path}"
    exit 1
  fi

  rm -rf "${target_dir}"
  mv "${extracted_root}" "${target_dir}"
  rm -rf "${target_dir}.tmp"
  log "Verified summary.txt and fastqc_data.txt for ${base_name}"
done

log "Finished extracting ${zip_count} FastQC archives"
