#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for mint-toolkit.
GH_REPO="https://github.com/mintoolkit/mint"
TOOL_NAME="mint-toolkit"
TOOL_TEST="mint --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
	# TODO: Adapt this. By default we simply list the tag names from GitHub releases.
	# Change this function if mint-toolkit has other means of determining installable versions.
	list_github_tags
}

get_url() {
	local -r version="$1"
	local -r arch="$(get_arch)"
	local -r platform="$(get_platform)"
	local filename

	if [[ ${arch} == "arm64" ]] && [[ ${platform} == "linux" ]]; then
		filename="dist_linux_arm64.tar.gz"
	elif [[ ${arch} == "arm" ]] && [[ ${platform} == "linux" ]]; then
		filename="dist_linux_arm.tar.gz"
	elif [[ ${arch} == "amd64" ]] && [[ ${platform} == "linux" ]]; then
		filename="dist_linux.tar.gz"
	elif [[ ${arch} == "amd64" ]] && [[ ${platform} == "darwin" ]]; then
		filename="dist_mac.zip"
	elif [[ ${arch} == "arm64" ]] && [[ ${platform} == "darwin" ]]; then
		filename="dist_mac_m1.zip"
	else
		fail "Unsupported platform/arch"
	fi

	echo "$GH_REPO/releases/download/${version}/${filename}"
}

download_release() {
	local -r version="$1"
	local -r filename="$2"

	local -r url="$(get_url "${version}")"
	echo "* Downloading $TOOL_NAME release $version..."
	curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
	local -r install_type="$1"
	local -r version="$2"
	local -r install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"
		cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

		# TODO: Assert mint-toolkit executable exists.
		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}

get_arch() {
	local -r machine="$(uname -m)"

	if [[ ${machine} == "arm64" ]] || [[ ${machine} == "aarch64" ]]; then
		echo "arm64"
	elif [[ ${machine} == *"arm"* ]] || [[ ${machine} == *"aarch"* ]]; then
		echo "arm"
	else
		echo "amd64"
	fi
}

get_platform() {
	uname | tr '[:upper:]' '[:lower:]'
}
