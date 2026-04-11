#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd "${script_dir}/.." && pwd)"
report_root="${project_dir}/trimmomatic/fastqc_trimmed/reports"
extract_dir="${project_dir}/trimmomatic/fastqc_trimmed_extracted"
log_dir="${extract_dir}/logs"
log_file="${log_dir}/extract_fastqc_trimmed_reports.log"

mkdir -p "${extract_dir}" "${log_dir}"
touch "${log_file}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S %Z'
}

log() {
  printf '[%s] %s\n' "$(timestamp)" "$*" | tee -a "${log_file}"
}

shopt -s nullglob
zip_paths=("${report_root}"/*/*_fastqc.zip)

log "Starting trimmed FastQC archive extraction"
log "Report root: ${report_root}"
log "Extraction directory: ${extract_dir}"

if [[ "${#zip_paths[@]}" -eq 0 ]]; then
  log "No trimmed FastQC zip archives found under ${report_root}"
  exit 1
fi

zip_count=0
for zip_path in "${zip_paths[@]}"; do
  zip_count=$((zip_count + 1))
  base_name="$(basename "${zip_path}" .zip)"
  target_dir="${extract_dir}/${base_name}"
  temp_dir="${extract_dir}/.${base_name}.tmp"

  log "Extracting ${zip_path}"
  rm -rf "${temp_dir}"
  mkdir -p "${temp_dir}"
  unzip -q -o "${zip_path}" -d "${temp_dir}"

  extracted_root="${temp_dir}/${base_name}"
  if [[ ! -f "${extracted_root}/summary.txt" || ! -f "${extracted_root}/fastqc_data.txt" ]]; then
    log "Missing expected FastQC files in ${zip_path}"
    exit 1
  fi

  rm -rf "${target_dir}"
  mv "${extracted_root}" "${target_dir}"
  rm -rf "${temp_dir}"
  log "Verified summary.txt and fastqc_data.txt for ${base_name}"
done

log "Finished extracting ${zip_count} trimmed FastQC archives"
