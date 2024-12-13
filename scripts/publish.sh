#!/usr/bin/env bash

set -eu
set -o pipefail

readonly ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
readonly BIN_DIR="${ROOT_DIR}/.bin"
readonly BUILD_DIR="${ROOT_DIR}/build"

# shellcheck source=SCRIPTDIR/.util/tools.sh
source "${ROOT_DIR}/scripts/.util/tools.sh"

# shellcheck source=SCRIPTDIR/.util/print.sh
source "${ROOT_DIR}/scripts/.util/print.sh"

function main {
  local buildpack_archive image_ref token
  token=""

  while [[ "${#}" != 0 ]]; do
    case "${1}" in
    --buildpack-archive | -b)
      buildpack_archive="${2}"
      shift 2
      ;;

    --image-ref | -i)
      image_ref+=("${2}")
      shift 2
      ;;

    --token | -t)
      token="${2}"
      shift 2
      ;;

    --help | -h)
      shift 1
      usage
      exit 0
      ;;

    "")
      # skip if the argument is empty
      shift 1
      ;;

    *)
      util::print::error "unknown argument \"${1}\""
      ;;
    esac
  done

  if [[ -z "${image_ref:-}" ]]; then
    usage
    echo
    util::print::error "--image-ref is required"
  fi

  if [[ -z "${buildpack_archive:-}" ]]; then
    util::print::info "Using default buildpack archive path: ${BUILD_DIR}/buildpack.tgz"
    buildpack_archive="${BUILD_DIR}/buildpack.tgz"
  fi

  repo::prepare

  tools::install "${token}"

  buildpack_type=buildpack
  if [ -f "${ROOT_DIR}/extension.toml" ]; then
    buildpack_type=extension
  fi

  buildpack::publish "${image_ref}" "${buildpack_type}"
}

function usage() {
  cat <<-USAGE
package.sh --version <version> [OPTIONS]

Packages a buildpack or an extension into a buildpackage .cnb file.

OPTIONS
  -h, --help                          Prints the command usage
  -b, --buildpack-archive <filepath>  Path to the buildpack arhive (default: ${BUILD_DIR}/buildpack.tgz) (optional)
  -i, --image-ref <ref>               List of image reference to publish to (required)
  -t, --token <token>                 Token used to download assets from GitHub (e.g. jam, pack, etc) (optional)
USAGE
}

function repo::prepare() {
  util::print::title "Preparing repo..."

  mkdir -p "${BIN_DIR}"
  mkdir -p "${BUILD_DIR}"

  export PATH="${BIN_DIR}:${PATH}"
}

function tools::install() {
  local token
  token="${1}"

  util::tools::pack::install \
    --directory "${BIN_DIR}" \
    --token "${token}"
}

function buildpack::publish() {

  local image_ref buildpack_type
  image_ref="${1}"
  buildpack_type="${2}"

  util::print::title "Publishing ${buildpack_type}... ${image_ref}"

  which pack

  mkdir ${BUILD_DIR}/cnbdir
  tar -xvf ${BUILD_DIR}/buildpack.tgz -C ${BUILD_DIR}/cnbdir

  pack \
    buildpack package $image_ref \
    --path ${BUILD_DIR}/cnbdir \
    --format image \
    --publish

  rm -rf ${BUILD_DIR}/cnbdir
}

main "${@:-}"