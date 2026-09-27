# shellcheck shell=bash
# Source every library file. GZ_LIB is the directory of this file.
GZ_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install/lib/log.sh
source "${GZ_LIB}/log.sh"
# shellcheck source=install/lib/fs.sh
source "${GZ_LIB}/fs.sh"
# shellcheck source=install/lib/portage.sh
source "${GZ_LIB}/portage.sh"
